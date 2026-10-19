defmodule Kantele.World.InquiryHandlers.GiveItem do
  @moduledoc """
  LPC `ask_me_1` / `ask_me_2` 类「问一句、发一件」问询（`kind = "give_item"`）。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "give_item"
        item = "shaolin:huwan"        # 发放的 item_id（LPC new("/d/shaolin/obj/"+name)）
        match = "huwan"               # present(name, me) 匹配词；缺省取 item_id 尾段
        count = "huju_count"          # 共享库存键（LPC set("huju_count", N)）；缺省无限
        unique = true                 # LPC ask_me_1 的 present(name, me) 检查；false 跳过
        family = "少林派"             # 限门派；缺省不限
        vision_name = "道相"          # message_vision 里的 NPC 短名；缺省用角色名
        success = "拿去吧。..."        # LPC 返回值（发给玩家）
        already = "你现在身上..."      # 已有时的返回值（自动加敬称）
        family_deny = "与本派..."      # 非本门时的返回值（自动加敬称）
        exhausted = "抱歉...发完了。"  # 库存耗尽时的返回值
      }

  ## 与 LPC 的差异

  - `RANK_D->query_respect` 用 `NpcActions.Helpers.respect/1`（暂统一「大侠」）。
  - `message_vision` 用 `Helpers.broadcast/3`（`$N` → `{npc}`，行动者看到「你」）。
  - 库存扣减不在 NPC 进程直接做：玩家侧确认发出后回发 `npc/inquiry_consume`，
    由 NPC 进程自减（`inquiry_state`），避免「回执丢失仍扣库存」。

  ## 并发说明（@todo）

  NPC 侧读到 `remaining` 后才在玩家侧发放，跨进程回执存在极窄的竞态：同一 tick
  内两人同时问会都看到旧库存。LPC 在 NPC 线程内同步扣减无此问题。后续可改为
  NPC 侧预留（先减，玩家侧失败时回补）。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.World.Item
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "item")) -> conn
      Map.get(data, :asker_id) != character.id -> conn
      true -> run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    cond do
      family_denied?(character, config) ->
        reply(conn, Helpers.respect(character) <> family_deny_text(config))

      unique?(config) and carries?(character, config) ->
        reply(conn, Helpers.respect(character) <> already_text(config))

      exhausted?(data) ->
        reply(conn, Map.get(config, "exhausted") || "抱歉，你来得不是时候，已经发完了。")

      true ->
        give(conn, config, data)
    end
  end

  defp give(conn, config, data) do
    item_id = config["item"]

    case Items.get(item_id) do
      {:ok, item} ->
        conn = Helpers.give_item(conn, item_id)
        conn = reply(conn, Map.get(config, "success") || "拿去吧。")
        conn = broadcast(conn, data, config, item, item_id)
        consume(data, config)
        conn

      _ ->
        conn
    end
  end

  defp broadcast(conn, data, config, item, item_id) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(config, "vision_name") || Map.get(data, :npc_name) || "对方"
        item_name = item.name || item_id
        Helpers.broadcast(conn, room_id, "#{npc_name}给$N一件#{item_name}。\n")

      _ ->
        conn
    end
  end

  defp consume(%{npc_pid: pid}, %{"count" => count_key})
       when is_pid(pid) and is_binary(count_key) do
    send(pid, %Kalevala.Event{
      from_pid: self(),
      topic: "npc/inquiry_consume",
      data: %{count_key: count_key}
    })
  end

  defp consume(_data, _config), do: :ok

  defp exhausted?(%{remaining: remaining}) when is_integer(remaining), do: remaining <= 0
  defp exhausted?(_data), do: false

  defp unique?(config) do
    case Map.get(config, "unique", true) do
      false -> false
      "false" -> false
      _ -> true
    end
  end

  defp carries?(character, config) do
    item_id = config["item"]
    match = Map.get(config, "match") || item_id_suffix(item_id)

    Enum.any?(character.inventory || [], fn instance ->
      instance.item_id == item_id or
        item_id_suffix(instance.item_id) == match or
        Item.matches?(Item.instance_item(instance), match)
    end)
  end

  defp item_id_suffix(item_id) when is_binary(item_id) do
    item_id |> String.split(":") |> List.last()
  end

  defp item_id_suffix(_item_id), do: nil

  defp family_denied?(character, config) do
    case Map.get(config, "family") do
      family when is_binary(family) and family != "" -> family_name(character) != family
      _ -> false
    end
  end

  defp family_name(%{meta: %{family: family}}) when is_map(family), do: Family.name(family)
  defp family_name(_character), do: nil

  defp family_deny_text(config),
    do: Map.get(config, "family_deny") || "与本派素无来往，不知此话从何谈起？"

  defp already_text(config),
    do: Map.get(config, "already") || "你现在身上已经有这样东西了。"

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
