defmodule Kantele.Character.AnswerCommand do
  @moduledoc """
  回答命令：`answer <类型>` / `answer <玩家> <消息>` / `answer Y|N`

  对应 LPC cmds/std/answer.c 与 moye.c `do_answer`。

  三条路径（按优先级）：

  1. Forge 路径：处于 `Forging` 会话 status=="answer_type" 时，
     `answer <类型>` 把选择转交莫邪进程裁决（room/forge_answer）。

  2. quest_gift 路径：`answer Y|N`（或 是/否）。
     读 `temp[:quest_gift]` = %{npc, obj, gongxian}：
     - Y：扣除门贡 gongxian，发放物品 obj，清 temp
     - N：婉拒，清 temp
     由 `AskCommand` 在 `ask <npc> quest` 时设置 temp[:quest_gift]。

  3. ask_you 路径：`answer <玩家> <消息>`。
     读 `temp[:ask_you]`（由 `ask <玩家>` 设置），在房间广播回答。

  否则走 stub 行为（回答系统/你要回答什么）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Communication
  alias Kantele.World.Forging
  alias Kantele.World.Invasion
  alias Kantele.World.Items
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.NpcActions.Helpers, as: NpcHelpers
  alias Kalevala.World.Item.Instance

  # A-5-c C4：康熙 ob_list（kangxi.c:121-140，18 项，含重复权重，不可去重）
  @ob_list [
    "clone_lib:linghui1",
    "clone_lib:linghui1",
    "clone_lib:lingzhi1",
    "clone_lib:lingzhi2",
    "clone_lib:full1",
    "clone_lib:full1",
    "clone_lib:xuelian1",
    "clone_lib:xuelian2",
    "clone_lib:neili1",
    "clone_lib:neili2",
    "clone_lib:renshen1",
    "clone_lib:renshen2",
    "clone_lib:va1",
    "clone_lib:va2",
    "clone_lib:va3",
    "clone_lib:va4",
    "clone_lib:va5",
    "clone_lib:va6"
  ]

  # chinesed.c:18-19
  @c_num ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    case maybe_forge(conn, rest) do
      {:ok, conn} -> conn
      :passthrough ->
        case handle_dianshi(conn, rest) do
          {:ok, conn} -> conn
          :passthrough ->
            case handle_quest_gift(conn, rest) do
              {:ok, conn} -> conn
              :passthrough ->
                case handle_ask_you(conn, rest) do
                  {:ok, conn} -> conn
                  :passthrough -> stub_message(conn)
                end
            end
        end
    end
  end

  def run(conn, %{}) do
    case maybe_forge(conn, nil) do
      {:ok, conn} -> conn
      :passthrough ->
        # 殿试出题期间裸 answer（无 arg）：LPC do_answer(nil) →
        # `say 你要回答什么?`（kangxi.c:153-154）；无题时保持原 stub。
        case handle_dianshi(conn, "") do
          {:ok, conn} -> conn
          :passthrough -> stub_empty(conn)
        end
    end
  end

  # ---- Forge 路径（保持原有逻辑） ----

  defp maybe_forge(conn, type) do
    character = conn.character
    session = Forging.get(character.id)

    if is_nil(session) or session.status != "answer_type" or is_nil(type) or
         String.trim(type) == "" do
      :passthrough
    else
      conn
      |> event("room/forge_answer", %{
        type: String.trim(type),
        target: "moye",
        from_id: character.id,
        from_name: character.name,
        reply_to: self()
      })
      |> then(fn conn -> {:ok, conn} end)
    end
  end

  # ---- quest_gift 路径：answer Y|N ----

  defp handle_quest_gift(conn, rest) do
    character = conn.character
    quest_gift = PlayerMeta.get_temp(character.meta, :quest_gift)
    answer = String.downcase(String.trim(rest))

    case {quest_gift, answer} do
      {%{npc: npc, obj: obj, gongxian: gongxian}, answer}
          when answer in ["y", "yes", "是"] ->
        accept_quest_gift(conn, character, npc, obj, gongxian)

      {%{npc: _npc, obj: _obj, gongxian: _gongxian}, answer}
          when answer in ["n", "no", "否"] ->
        decline_quest_gift(conn, character)

      {nil, _} ->
        :passthrough

      {_, _} ->
        {:ok,
         conn
         |> render(CommandView, "text", %{text: "请输入 Y 接受或 N 拒绝。\n"})
         |> prompt(CommandView, "prompt", %{})}
    end
  end

  defp accept_quest_gift(conn, character, npc, obj, gongxian) do
    stats = character.meta.stats || %Stats{}
    current_gongxian = stats.gongxian || 0

    cond do
      current_gongxian < gongxian ->
        {:ok,
         conn
         |> render(CommandView, "text", %{text: "你的门贡不足，无法接受#{npc}的赠予。\n"})
         |> prompt(CommandView, "prompt", %{})}

      true ->
        item = Kantele.World.Item.fetch(obj)
        instance = %Instance{
          id: Instance.generate_id(),
          item_id: item.id,
          created_at: DateTime.utc_now(),
          item: item
        }

        new_stats = %{stats | gongxian: current_gongxian - gongxian}
        new_meta =
          character.meta
          |> Map.put(:stats, new_stats)
          |> PlayerMeta.delete_temp(:quest_gift)

        new_character = %{
          character
          | meta: new_meta,
            inventory: [instance | character.inventory]
        }

        {:ok,
         conn
         |> put_character(new_character)
         |> render(
           CommandView,
           "text",
           %{text: "你从#{npc}处接过了#{item.name}，支付了#{gongxian}门贡。\n"}
         )
         |> prompt(CommandView, "prompt", %{})}
    end
  end

  defp decline_quest_gift(conn, character) do
    new_meta = PlayerMeta.delete_temp(character.meta, :quest_gift)
    new_character = %{character | meta: new_meta}

    {:ok,
     conn
     |> put_character(new_character)
     |> render(CommandView, "text", %{text: "你婉拒了赠予。\n"})
     |> prompt(CommandView, "prompt", %{})}
  end

  # ---- 殿试路径（A-5-c C4）：answer xxx 对应康熙 do_answer ----

  # 康熙殿试作答（A-5-c C4，对应 LPC d/beijing/npc/kangxi.c:115-196 do_answer）。
  # 前置：ask <康熙> 领赏（BeijingReward handler）成功出题，玩家 meta.env[:waidi]
  # 带 word/born_time/number/npc_name/npc_room_id；无 word 时 passthrough。
  # 门序（kangxi.c 原序）：无 record -> 未全歼 -> born_time 过期 -> 空 arg ->
  # 答错（两段 say + delete waidi）-> 答对（奖励 + 两段 say + 全服圣旨 + delete waidi）。
  defp handle_dianshi(conn, rest) do
    character = conn.character
    waidi = dianshi_waidi(character)

    if is_binary(Map.get(waidi, :word)) do
      {:ok, dianshi_gates(conn, character, waidi, rest)}
    else
      :passthrough
    end
  end

  defp dianshi_gates(conn, character, waidi, rest) do
    record = Invasion.record()
    npc_name = Map.get(waidi, :npc_name) || "康熙大帝"
    room_id = Map.get(waidi, :npc_room_id)

    cond do
      not Map.get(record, :exists) ->
        npc_say(conn, room_id, npc_name, "如今并无异族联军入侵呀！")

      not Map.get(record, :all_killed) ->
        npc_say(conn, room_id, npc_name, "朕并未恩准赏赐，尔等速速离去！")

      Map.get(waidi, :born_time) != Map.get(record, :born_time) ->
        npc_say(conn, room_id, npc_name, "尔之赏赐已过期了！")

      String.trim(rest) == "" ->
        # LPC `if (!arg) return command("say 你要回答什么?");`（半角问号，原文如此）
        npc_say(conn, room_id, npc_name, "你要回答什么?")

      rest != Map.get(waidi, :word) ->
        # LPC 比较原始 arg：`me->query("waidi/word") != arg`（不做 trim）
        dianshi_wrong(conn, character, room_id, npc_name)

      true ->
        dianshi_correct(conn, character, waidi, room_id, npc_name)
    end
  end

  # 答错（kangxi.c:156-163）：两段 say + delete("waidi")
  defp dianshi_wrong(conn, character, room_id, npc_name) do
    character = delete_waidi(character)

    conn
    |> put_character(character)
    |> npc_say(
      room_id,
      npc_name,
      "可惜，这位" <> NpcHelpers.respect(character) <> "虽然武艺出众,但是目不识丁，朕不能给你赏赐了。"
    )
    |> npc_say(room_id, npc_name, "你还是速速离去吧！")
    |> prompt(CommandView, "prompt", %{})
  end

  # 答对（kangxi.c:165-195）：奖励公式 + 发放 + 两段 say + 全服圣旨 + delete("waidi")
  defp dianshi_correct(conn, character, waidi, room_id, npc_name) do
    number = Map.get(waidi, :number) || 0

    # LPC：pot = 100 * waidi/number + random(300)；gn = number + random(2)，上限 10
    pot = 100 * number + :rand.uniform(300) - 1
    gn = min(number + :rand.uniform(2) - 1, 10)

    item_id = Enum.random(@ob_list)
    item = item_info(item_id)

    # 黄金 + 丹药入包（LPC gold->move(me,1); ob->move(me,1)）
    conn = Helpers.give_item(conn, "clone_lib:gold", meta: %{"amount" => gn})
    conn = if item_id, do: Helpers.give_item(conn, item_id), else: conn

    # 以 give_item 后的最新角色为基准加潜能（同 心魔 块的次序陷阱注释）
    character = current_character(conn, character)
    character = add_potential(character, pot)
    character = delete_waidi(character)
    Records.save(character)
    conn = put_character(conn, character)

    conn
    |> npc_say(
      room_id,
      npc_name,
      "不错，不错，这位" <> NpcHelpers.respect(character) <> "不但武艺出众,文采亦是不菲，朕要大大的赏赐于你。"
    )
    |> announce_edict(character, pot, gn, item)
    |> prompt(CommandView, "prompt", %{})
  end

  defp item_info(item_id) do
    case Items.get(item_id) do
      {:ok, item} -> %{name: item.name, unit: Map.get(item.meta, :unit) || "个"}
      # 18 项 ob_list 在本批全部定义后不可达；防御性占位保持圣旨句式完整
      _ -> %{name: "赏赐之物", unit: "件"}
    end
  end

  defp add_potential(character, pot) do
    stats = character.meta.stats
    put_in(character.meta.stats.potential, (stats.potential || 0) + pot)
  end

  defp delete_waidi(character) do
    env = Map.delete(character.meta.env || %{}, :waidi)
    %{character | meta: Map.put(character.meta, :env, env)}
  end

  # LPC message("invasion", ..., users())：全服圣旨（ex 走 waidi 频道广播，
  # 与 invasion.ex 的 announce 同通道）。文案 kangxi.c:186-191 逐字（去 ANSI 色）。
  defp announce_edict(conn, character, pot, gn, item) do
    item_part = "#{item.name}一#{item.unit}"

    text =
      "【外敌入侵】大内总管[Danei zongguan]：圣旨到！\n" <>
        "            传皇上口谕：\n" <>
        "            赐抗敌义士#{character.name}(#{character.id})潜能#{chinese_number(pot)}点，" <>
        "黄金#{chinese_number(gn)}两，#{item_part}。\n" <>
        "                                         钦此！\n"

    Communication.announce("waidi", text)
    conn
  end

  # chinesed.c chinese_number 逐条移植（0..<10000 覆盖 pot/gn 全域）
  defp chinese_number(i) when i < 0, do: "负" <> chinese_number(-i)

  defp chinese_number(i) when i < 11 do
    Enum.at(@c_num, i)
  end

  defp chinese_number(i) when i < 20, do: "十" <> Enum.at(@c_num, i - 10)

  defp chinese_number(i) when i < 100 do
    if rem(i, 10) != 0 do
      Enum.at(@c_num, div(i, 10)) <> "十" <> Enum.at(@c_num, rem(i, 10))
    else
      Enum.at(@c_num, div(i, 10)) <> "十"
    end
  end

  defp chinese_number(i) when i < 1000 do
    case rem(i, 100) do
      0 -> Enum.at(@c_num, div(i, 100)) <> "百"
      r when r < 10 -> Enum.at(@c_num, div(i, 100)) <> "百零" <> chinese_number(r)
      r -> Enum.at(@c_num, div(i, 100)) <> "百" <> chinese_number(r)
    end
  end

  defp chinese_number(i) when i < 10_000 do
    case rem(i, 1000) do
      0 -> Enum.at(@c_num, div(i, 1000)) <> "千"
      r when r < 100 -> Enum.at(@c_num, div(i, 1000)) <> "千零" <> chinese_number(r)
      r -> Enum.at(@c_num, div(i, 1000)) <> "千" <> chinese_number(r)
    end
  end

  defp chinese_number(i) do
    # i < 100_000_000：万段（pot 实际远小于此，保真兜底）
    case rem(i, 10_000) do
      0 -> chinese_number(div(i, 10_000)) <> "万"
      r when r < 1000 -> chinese_number(div(i, 10_000)) <> "万零" <> chinese_number(r)
      r -> chinese_number(div(i, 10_000)) <> "万" <> chinese_number(r)
    end
  end

  defp dianshi_waidi(character) do
    env = character.meta.env || %{}
    Map.get(env, :waidi) || %{}
  end

  defp current_character(conn, fallback),
    do: conn.private.update_character || fallback

  # LPC command("say ...")：房间广播（康熙在场）
  defp npc_say(conn, room_id, npc_name, text) when is_binary(room_id) do
    Helpers.broadcast_vision(conn, room_id, "#{npc_name}说道：#{text}\n")
  end

  defp npc_say(conn, _room_id, _npc_name, _text), do: conn

  # ---- ask_you 路径：answer <玩家> <消息> ----

  defp handle_ask_you(conn, rest) do
    character = conn.character
    asker_name = PlayerMeta.get_temp(character.meta, :ask_you)

    case {asker_name, rest} do
      {asker_name, rest} when is_binary(asker_name) and is_binary(rest) ->
        case split_ask_you(rest) do
          {target, msg} when is_binary(target) and is_binary(msg) ->
            if String.trim(msg) != "" and String.downcase(target) == String.downcase(asker_name) do
              broadcast_ask_you(conn, character, asker_name, msg)
            else
              :passthrough
            end

          _ ->
            :passthrough
        end

      {nil, _} ->
        :passthrough

      {_, _} ->
        :passthrough
    end
  end

  defp split_ask_you(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [target, msg] -> {String.trim(target), String.trim(msg)}
      [target] -> {String.trim(target), ""}
      _ -> {nil, nil}
    end
  end

  defp broadcast_ask_you(conn, character, asker_name, msg) do
    room_id = character.room_id
    template = "{npc} 回答 #{asker_name}: '#{msg}'"

    new_meta = PlayerMeta.delete_temp(character.meta, :ask_you)
    new_character = %{character | meta: new_meta}

    {:ok,
     conn
     |> put_character(new_character)
     |> Helpers.broadcast_vision(room_id, template)
     |> assign(:prompt, false)}
  end

  # ---- Stub（保留原有） ----

  defp stub_message(conn) do
    conn
    |> render(CommandView, "text", %{text: "回答系统目前不支持该选项。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp stub_empty(conn) do
    conn
    |> render(CommandView, "text", %{text: "你要回答什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
