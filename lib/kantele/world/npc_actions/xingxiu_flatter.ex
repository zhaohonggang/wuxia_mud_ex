defmodule Kantele.World.NpcActions.XingxiuFlatter do
  @moduledoc """
  星宿派丁春秋 `flatter`（拍马）—— LPC `kungfu/class/xingxiu/ding.c:181-200`
  的 `do_flatter(string arg)`。

  这是 GAP #812 两步拜师的后半段：`attempt_apprentice` 在数字门通过后只落
  `pending/flatter` 并播提示，不立即收徒；本 handler 才做文案匹配与 recruit。

  ## LPC 原文逐条对应

  1. `if (!this_player()->query_temp("pending/flatter")) return 0;`
     → 无 pending 时返回 `:not_handled`，交回全局命令且不播任何文案。
  2. `if (!arg) return notify_fail("你说老仙什么？\\n");`
     → 私发原文；此处**不**清 pending（LPC 在 notify_fail 之前没有 set_temp）。
  3. `this_player()->set_temp("pending/flatter", 0);`
     → `PlayerMeta.delete_temp/2`（会话级）。
  4. `message_vision("$N大声说道：" + arg + "\\n", this_player());`
     → 房间广播，`$N` 由 `VisionView` 渲染为「你」/玩家名。
  5. `strsrch(arg,"星宿老仙")>=0 && (德配天地|威震寰宇|古今无比之一)`
     → 两个条件必须同时成立；只含其一走拒绝分支。
  6. `command("smile")` → data/emoted.o 的旁观者文案「丁春秋愉快地微笑着。」。
  7. `command("say 这还差不多。")` → NPC 房间广播；UCL 的 `accept_msg` 同文案
     在交给 `FamilyEvent` 前删除，避免玩家侧再私发一遍造成重复。
  8. `welcome(this_player()); command("recruit " + id);`
     → 构造 `family/result` 交给 `Kantele.Character.FamilyEvent`，由其复用
     `recruit_gate?/3` 与门派写入路径（`permit_recruit` 的判师/他派台词也在其中）。
  9. 拒绝分支 `command("say 你如此不把我放在眼里，我怎能收你？")`
     → NPC 房间广播；注意与第一步拒绝文案「不把老仙放在眼里」用字不同。

  ## 注册与安全

  只注册 `xiyu:riyuedong` 且触发 NPC 确为丁春秋；其它房间/其它带 `flatter`
  的 NPC（如神龙教洪某）不受影响。既符合 LPC `add_action` 的房间局部性，
  也避免全局动词抢走别的 NPC 的动作。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kalevala.Event
  alias Kantele.Character.FamilyEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Helpers

  @room_id "xiyu:riyuedong"
  @npc_name "丁春秋"
  @npc_aliases ["丁春秋", "xingxiu_ding", "ding chunqiu", "ding"]
  @default_pending_key "pending/flatter"
  @title_word "星宿老仙"
  @praise_words ["德配天地", "威震寰宇", "古今无比"]

  @impl true
  def run(conn, %{room_id: room_id, trailing: trailing, npc: npc}) when is_binary(room_id) do
    cond do
      room_id != @room_id or not dingchunqiu?(npc) ->
        :not_handled

      # #816 LPC ding.c:122-136：持鼎进屋时 init() 直接 kill_ob 并 `return`，
      # 根本不会走 `add_action("do_flatter", "flatter")`。ex 的动词是静态注册，
      # 这里按同一前置条件拒绝，等价于 LPC 里「没有这个动作」。
      carrying_swmuding?(current(conn)) ->
        :not_handled

      true ->
        do_flatter(conn, trailing || "", npc)
    end
  end

  def run(_conn, _params), do: :not_handled

  defp dingchunqiu?(%{name: name, meta: meta}) do
    name == @npc_name or Enum.any?(aliases(meta), &(&1 in @npc_aliases))
  end

  defp dingchunqiu?(_npc), do: false

  defp carrying_swmuding?(character) when is_map(character) do
    Helpers.carries?(character, "shenmu wangding") or Helpers.carries?(character, "swmuding")
  end

  defp carrying_swmuding?(_), do: false

  defp aliases(%{aliases: aliases}) when is_list(aliases), do: aliases
  defp aliases(_meta), do: []

  defp do_flatter(conn, arg, npc) do
    apprentice = apprentice(npc)
    key = pending_key(apprentice)
    character = current(conn)
    meta = character.meta || %PlayerMeta{}

    if truthy?(PlayerMeta.get_temp(meta, key)) do
      if arg == "" do
        Helpers.render(conn, pending_text(apprentice, :pending_recruit_no_arg, "你说老仙什么？\n"))
      else
        npc_name = npc_name(npc)

        conn =
          conn
          |> Helpers.delete_temp(key)
          |> Helpers.broadcast(@room_id, "$N大声说道：#{arg}\n")

        if flattering?(arg) do
          conn
          |> Helpers.broadcast(@room_id, "#{npc_name}愉快地微笑着。\n")
          |> Helpers.say(@room_id, npc_name, pending_text(apprentice, :accept_msg, "这还差不多。"))
          |> recruit(npc, apprentice)
        else
          Helpers.say(
            conn,
            @room_id,
            npc_name,
            pending_text(apprentice, :pending_recruit_fail, "你如此不把我放在眼里，我怎能收你？")
          )
        end
      end
    else
      # LPC `return 0`：玩家没先触发 attempt_apprentice，本动词不处理。
      :not_handled
    end
  end

  defp flattering?(arg) do
    String.contains?(arg, @title_word) and Enum.any?(@praise_words, &String.contains?(arg, &1))
  end

  defp recruit(conn, npc, apprentice) do
    character = current(conn)
    teach = teach(npc)
    family = teach && Map.get(teach, :family)

    # FamilyEvent 从 conn.character 取快照；先把已删除 pending 的当前角色
    # 同步过去，避免收徒落盘时把 pending/flatter 又写回来。
    conn = %{conn | character: character}

    if is_binary(family) and byte_size(family) > 0 do
      # 成功台词已由本 handler 以 NPC `command("say ...")` 广播；去掉
      # accept_msg 防止私发重复。还必须去掉 pending_recruit，否则 FamilyEvent
      # 会把这次 recruit 当成又一次 attempt_apprentice，重新落 pending 而不收徒。
      recruit_apprentice =
        apprentice
        |> Map.delete(:accept_msg)
        |> Map.delete(:pending_recruit)

      FamilyEvent.result(
        conn,
        %Event{
          topic: "family/result",
          data: %{
            ok: true,
            family: family,
            master_id: Map.get(npc, :id),
            master_name: npc_name(npc),
            student_name: character.name,
            teach: teach,
            apprentice: recruit_apprentice
          }
        }
      )
    else
      conn
    end
  end

  defp apprentice(%{meta: %{apprentice: apprentice}}) when is_map(apprentice), do: apprentice
  defp apprentice(_npc), do: %{}

  defp teach(%{meta: %{teach: teach}}) when is_map(teach), do: teach
  defp teach(_npc), do: nil

  defp pending_key(apprentice) do
    case Map.get(apprentice, :pending_recruit) do
      verb when is_binary(verb) and byte_size(verb) > 0 -> "pending/#{verb}"
      _ -> @default_pending_key
    end
  end

  defp pending_text(apprentice, key, default) do
    case Map.get(apprentice, key) do
      text when is_binary(text) and byte_size(text) > 0 -> text
      _ -> default
    end
  end

  defp npc_name(%{name: name}) when is_binary(name) and byte_size(name) > 0, do: name
  defp npc_name(_npc), do: @npc_name

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_), do: true

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
