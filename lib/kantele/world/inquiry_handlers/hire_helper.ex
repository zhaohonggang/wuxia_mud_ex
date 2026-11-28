defmodule Kantele.World.InquiryHandlers.HireHelper do
  @moduledoc """
  侠客岛黄衣使者雇助服务（`d/xiakedao/npc/renter.c:116-297`）。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "hire_helper"
        mode = "list"                 # ask_rent；缺省
        min_weiwang = 1000
        min_score = 10000
        min_combat_exp = 100000
        max_dps = 30                  # LPC combat/DPS；Stats 未建模时按 0 放行
        max_wpk = 30                  # LPC combat/WPK；同上
      }

      value = {
        kind = "hire_helper"
        mode = "hire"                 # accept_ask → try_to_hire
        helper = "xiakedao_helper_one" # 可按 id/名字从 helpers 表选出
      }

  `mode = "list"` 按 LPC 顺序过七道门，随后把黄衣使者身边的师兄弟列表广播给房间；
  `mode = "hire"` 实现 `try_to_hire` 的「已有同门 → exp 比例 → 15 级价目表」，
  并把 `pending/rent/cost` / `pending/rent/helper` 写进玩家 temp，供后续 give 结算。

  与 LPC 的差异：

  - LPC 的 `combat/DPS`、`combat/WPK` 在 Ex 的 `Stats` 结构体里没有字段；本模块
    优先读 `meta.combat.dps` / `meta.stats.dps`（以及 `:wpk`），**未提供则按 0**，
    即不误伤没有该统计的角色。这是「只多不少」的可选扩展，不是删门。
  - LPC 的 helper 是真实 NPC 对象；Ex 侧用 `inquiry_state["rent_helpers"]` 里的
    描述表（id/name/npc_level/combat_exp/family）承载同一份数据，付款后再由
    `XiakedaoRentAccept` 落成真实 NPC 与跟随关系。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.NpcActions.Helpers

  # LPC renter.c:15-91 的 info 表；npcd.c 的 levels 表给出各 npc_level 的 combat_exp。
  @costs [10, 20, 25, 30, 35, 40, 50, 60, 80, 100, 150, 200, 300, 500, 700]
  @helper_exp [
    50_000,
    100_000,
    200_000,
    400_000,
    500_000,
    800_000,
    1_200_000,
    1_600_000,
    2_000_000,
    2_500_000,
    3_000_000,
    4_000_000,
    5_500_000,
    7_500_000,
    9_000_000
  ]

  @list_closings [
    "{npc}看了看{name}，道：“你想找谁帮你的忙，不妨和我说说。”\n",
    "{npc}对{name}道：“我的师兄弟水平各有高下，你找一个派得上用场的吧！”\n",
    "{npc}微微一笑，对{name}道：“你觉得谁合适？”\n"
  ]

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      case Map.get(config, "mode") || "list" do
        "hire" -> hire(conn, character, config, data)
        _ -> list_helpers(conn, character, config, data)
      end
    end
  end

  def run(conn, _config, _data), do: conn

  # ---- ask_rent ----

  defp list_helpers(conn, character, config, data) do
    helpers = helpers_of(config, data)

    cond do
      stat(character, :weiwang) < int_config(config, "min_weiwang", 1000) ->
        reply(conn, "你这点名头也能使唤人？算了吧！")

      stat(character, :score) < int_config(config, "min_score", 10_000) ->
        reply(conn, "你江湖阅历太浅，还是免了。")

      stat(character, :combat_exp) < int_config(config, "min_combat_exp", 100_000) ->
        reply(conn, "你的武功太差，想支使谁呀？")

      stat(character, :dps) > int_config(config, "max_dps", 30) ->
        reply(conn, "你这人，伤人太多，我们侠客岛的弟子可不能助纣为虐。")

      stat(character, :wpk) > int_config(config, "max_wpk", 30) ->
        reply(
          conn,
          "你这人呀！辣手无情，杀人无算，张兄李兄没找你算帐就不错了。"
        )

      hired = same_family_hired(character, npc_family(config, data)) ->
        reply(conn, "现在不是有#{helper_name(hired)}和你在一起么？你还想怎么样？")

      helpers == [] ->
        reply(conn, "我的师兄弟都走啦，你还是等两天再来吧。")

      true ->
        broadcast_list(conn, helpers, config, data)
    end
  end

  defp broadcast_list(conn, helpers, config, data) do
    room_id = Map.get(data, :npc_room_id)

    if is_binary(room_id) do
      header =
        "{npc}笑了笑，道：“现在我身边的师兄弟有这么几个，你看看吧。”\n" <>
          format_helpers(helpers) <> closing_line(config, data)

      Helpers.broadcast(conn, room_id, header)
    else
      conn
    end
  end

  defp format_helpers(helpers) do
    helpers
    |> Enum.with_index(1)
    |> Enum.map(fn {helper, index} ->
      name = helper_name(helper)
      id = helper_id(helper)
      level = helper_level(helper)

      format("%2d. %-27s  等级：%d\n", [index, "#{name}(#{id})", level])
    end)
    |> Enum.join()
  end

  defp closing_line(config, data) do
    case {Map.get(config, "closing"), Map.get(data, :closing_index)} do
      {line, _} when is_binary(line) -> line
      {_, index} when is_integer(index) -> Enum.at(@list_closings, rem(index, 3))
      _ -> Enum.at(@list_closings, :rand.uniform(3) - 1)
    end
  end

  # ---- accept_ask / try_to_hire ----

  defp hire(conn, character, config, data) do
    helpers = helpers_of(config, data)
    helper = find_helper(helpers, Map.get(config, "helper") || Map.get(data, :perform_name))

    cond do
      is_nil(helper) ->
        reply(
          conn,
          "你看了看我，疑问道：“你想干什么？是要找我的同门师兄弟么？”"
        )

      hired = same_family_hired(character, npc_family(config, data)) ->
        reply(conn, "#{helper_name(hired)}现在不是正和你在一起么？还不够啊？")

      character_exp(character) < div(helper_exp(helper) * 2, 3) ->
        reply(conn, "算了吧，#{helper_name(helper)}武功也强你太多，他可没兴趣帮你。")

      helper_exp(helper) * 2 < character_exp(character) ->
        reply(conn, "哦？你武功这么好，#{helper_name(helper)}恐怕帮不上你什么忙吧。")

      true ->
        set_pending(conn, character, helper, config)
    end
  end

  defp set_pending(conn, character, helper, config) do
    cost = cost_for(helper_level(helper), config)

    conn =
      conn
      |> Helpers.broadcast(
        npc_room_id_of(conn, character),
        "{npc}微微一笑，道：“好吧，不过你也得意思意思啊，我们侠客岛开销也不小的。”\n" <>
          "{npc}仔细考虑了一会儿，对{name}道：“这样吧，就" <>
          chinese_number(cost) <>
          "两黄金吧。”\n"
      )

    character = current(conn)

    pending = %{"cost" => cost, "helper" => normalize_helper(helper)}

    meta =
      character.meta
      |> PlayerMeta.put_temp("pending/rent/cost", cost)
      |> PlayerMeta.put_temp("pending/rent/helper", normalize_helper(helper))
      |> PlayerMeta.put_temp("pending/rent", pending)

    character = %{character | meta: meta}
    conn = put_character(conn, character)
    Records.save(character)
    conn
  end

  # ---- helpers ----

  @doc "从 NPC 侧 inquiry_state 或配置里取当前可雇的师兄弟列表"
  def helpers_of(config, data) do
    from_data = Map.get(data, :helpers) || Map.get(data, "helpers")
    from_config = Map.get(config, "helpers")

    [from_data, from_config]
    |> Enum.find(&is_list/1)
    |> case do
      nil -> []
      list -> Enum.map(list, &normalize_helper/1)
    end
  end

  defp normalize_helper(helper) when is_map(helper) do
    %{
      "id" => get(helper, "id") || get(helper, :id),
      "name" => helper_name(helper),
      "npc_level" => helper_level(helper),
      "combat_exp" => helper_exp(helper),
      "family" => get(helper, "family") || get(helper, :family) || "侠客岛"
    }
  end

  defp normalize_helper(_helper), do: nil

  defp find_helper(helpers, key) when is_binary(key) and key != "" do
    lowered = String.downcase(key)

    Enum.find(helpers, fn helper ->
      id = to_string(Map.get(helper, "id") || "")
      name = to_string(Map.get(helper, "name") || "")

      id == key or String.downcase(id) == lowered or name == key or
        String.downcase(name) == lowered
    end)
  end

  defp find_helper(_helpers, _key), do: nil

  defp helper_name(helper), do: get(helper, "name") || get(helper, :name) || "师弟"
  defp helper_id(helper), do: get(helper, "id") || get(helper, :id) || "?"

  defp helper_level(helper) do
    case get(helper, "npc_level") || get(helper, :npc_level) do
      level when is_integer(level) -> level
      level when is_binary(level) -> String.to_integer(level)
      _ -> 1
    end
  end

  defp helper_exp(helper) do
    case get(helper, "combat_exp") || get(helper, :combat_exp) do
      exp when is_integer(exp) and exp > 0 -> exp
      _ -> Enum.at(@helper_exp, helper_level(helper) - 1) || 50_000
    end
  end

  defp same_family_hired(character, family) do
    temp = Map.get(character.meta, :temp) || %{}

    hired =
      Map.get(temp, "hire") || Map.get(temp, :hire) ||
        Map.get(temp, "pending/rent/hire") || []

    if is_list(hired) do
      Enum.find(hired, fn
        helper when is_map(helper) ->
          helper_family(helper) == family

        _ ->
          false
      end)
    else
      nil
    end
  end

  defp helper_family(helper) do
    case get(helper, "family") || get(helper, :family) do
      nil -> "侠客岛"
      family -> family
    end
  end

  defp npc_family(config, data) do
    Map.get(data, :npc_family) || Map.get(data, "npc_family") ||
      Map.get(config, "family") || "侠客岛"
  end

  # ---- 数值 ----

  defp cost_for(level, config) do
    costs = Map.get(config, "costs") || @costs

    cost =
      if is_list(costs) and length(costs) >= 15 do
        Enum.at(costs, max(level, 1) - 1)
      else
        Enum.at(@costs, max(level, 1) - 1)
      end

    if is_integer(cost), do: cost, else: 10
  end

  defp stat(character, key) do
    meta = character.meta || %{}
    stats = Map.get(meta, :stats) || Map.get(meta, "stats") || %{}
    combat = Map.get(meta, :combat) || Map.get(meta, "combat") || %{}

    case Map.get(stats, key) || Map.get(stats, to_string(key)) ||
           Map.get(combat, key) || Map.get(combat, to_string(key)) do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  defp character_exp(character), do: stat(character, :combat_exp)

  defp int_config(config, key, default) do
    case Map.get(config, key) do
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
      _ -> default
    end
  end

  defp get(map, key) when is_map(map), do: Map.get(map, key)
  defp get(_map, _key), do: nil

  # LPC `chinese_number()`；雇助价目最大 700，这里覆盖到万位以便配置扩展。
  @digits ~w(零 一 二 三 四 五 六 七 八 九)
  @units ~w( 十 百 千)

  defp chinese_number(n) when is_integer(n) and n > 0 and n < 10_000 do
    digits = Integer.digits(n)
    last = length(digits) - 1

    digits
    |> Enum.with_index()
    |> Enum.reduce({"", false}, fn {digit, index}, {acc, pending_zero?} ->
      position = last - index

      cond do
        digit == 0 ->
          {acc, true}

        true ->
          unit = if position == 0, do: "", else: Enum.at(@units, position - 1)
          zero = if pending_zero? and acc != "", do: "零", else: ""
          {acc <> zero <> Enum.at(@digits, digit) <> unit, false}
      end
    end)
    |> elem(0)
  end

  defp chinese_number(n) when is_integer(n), do: Integer.to_string(n)

  # Elixir 1.13 没有 String.pad_leading 的 :trailing 选项，手写 %-27s。
  defp format("%2d. %-27s  等级：%d\n", [index, text, level]) do
    padded = text |> String.pad_trailing(27)
    format("%2d. %s  等级：%d\n", [index, padded, level])
  end

  defp format("%2d. %s  等级：%d\n", [index, text, level]) do
    String.pad_leading(to_string(index), 2) <>
      ". " <>
      text <>
      "  等级：" <>
      to_string(level) <> "\n"
  end

  defp npc_room_id_of(conn, character) do
    room_id = Map.get(character, :room_id)

    case {room_id, Map.get(conn, :private)} do
      {nil, %{npc_room_id: id}} -> id
      _ -> room_id
    end
  end

  # ---- 输出 ----

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(Kantele.Character.CommandView, "text", %{text: text <> "\n"})
    |> prompt(Kantele.Character.CommandView, "prompt", %{})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
