defmodule Kantele.World.NpcActions.XuedaoKneel do
  @moduledoc """
  血刀派 #794：善勇剃度（`kneel`）—— LPC `kungfu/class/xuedao/shanyong.c` 的 `do_kneel()`。

  Player 必须先 `ask 善勇 剃度`（见
  `Kantele.World.InquiryHandlers.XuedaoTonsure`）置 `pending/join_bonze`，再在本房间
  输入 `kneel` 才生效（LPC `if (!query_temp(...)) return 0;`）。

  ## LPC 原文逐条对应（`shanyong.c:131-149` `do_kneel`）

  1. `if (!me->query_temp("pending/join_bonze")) return 0;`
     → 未受请：`{:not_handled}`，交回全局命令。
  2. `message_vision("$N双手合十，恭恭敬敬地跪了下来。…将$N的头发尽数剃去。", me, this_object())`
     → 房间广播；`$N`（行动者=玩家）交给 VisionView 渲染成「你」，`$n`（善勇）
     替换为 NPC 名。
  3. `command("ke")` → 房间广播 `${npc_name}...`（LPC emote 条目）
  4. `me->set("class", "bonze")` → `meta.family.class`。玩家尚无任何门派时建
     `%{"class" => ...}` 的裸 family map，不伪造门派名/师父。
  5. `command("recruit " + me->query("id"))` → NPC 收徒说词（房间广播 say）。
  6. `delete_temp("pending/join_bonze")` → `PlayerMeta.delete_temp/2`。
  7. `return 1` → 返回更新后的 conn。

  ## 与 XueshanKneel 的差异

  - 无 title 设置（善勇不置 `title`）
  - 房间固定为 `xuedao:wangyougu`，NPC 为善勇
  - 说词为 血刀 文案

  ## 注册与安全

  只处理 `xuedao:wangyougu` 且 **触发 NPC 确为善勇** 的 `kneel`。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.NpcActions.Helpers

  @room_id "xuedao:wangyougu"
  @npc_name "善勇"
  @pending_key :pending_join_bonze
  @pending_key_lpc "pending/join_bonze"

  @impl true
  def run(conn, %{room_id: room_id, npc: npc}) when is_binary(room_id) do
    if room_id == @room_id and shanyong?(npc) do
      do_kneel(conn, npc)
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp shanyong?(%{name: name, meta: %{aliases: aliases}}) when is_list(aliases) do
    name == @npc_name or
      Enum.any?(aliases, &(&1 in [@npc_name, "xuedao_shanyong", "shan yong", "shan", "yong"]))
  end

  defp shanyong?(%{name: name}), do: name == @npc_name
  defp shanyong?(_), do: false

  defp do_kneel(conn, npc) do
    character = conn.private.update_character || conn.character
    meta = character.meta || %PlayerMeta{}

    if pending?(meta) do
      perform(conn, character, meta, npc)
    else
      # LPC `return 0`：交回命令解析，不播任何文案。
      :not_handled
    end
  end

  defp pending?(meta),
    do: truthy?(PlayerMeta.get_temp(meta, @pending_key)) or truthy?(PlayerMeta.get_temp(meta, @pending_key_lpc))

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_), do: true

  defp perform(conn, character, meta, npc) do
    npc_name = @npc_name

    conn =
      conn
      # LPC message_vision：$N=玩家跪下，$n=善勇剃发
      |> Helpers.broadcast(
        @room_id,
        "$N双手合十，恭恭敬敬地跪了下来。\n\n" <>
          "#{npc_name}伸出手掌，在$N头顶轻轻地摩挲了几下，将$N的头发尽数剃去。\n\n"
      )
      # LPC command("ke")：NPC emote
      |> Helpers.broadcast(@room_id, "#{npc_name}点了点头。\n")
      # LPC command("recruit <id>")：NPC 收徒说词
      |> Helpers.say(@room_id, npc_name, "既然你皈依我佛，我便收你为徒。")

    updated = %{character | meta: tonsured_meta(meta)}

    conn
    |> put_character(updated)
    |> persist(character.name)
  end

  defp tonsured_meta(meta) do
    temp =
      meta
      |> Map.get(:temp, %{})
      |> Map.delete(@pending_key)
      |> Map.delete(@pending_key_lpc)

    family =
      case Map.get(meta, :family) do
        family when is_map(family) -> Map.put(family, :class, "bonze")
        _ -> %{class: "bonze"}
      end

    meta
    |> Map.put(:temp, temp)
    |> Map.put(:family, family)
  end

  defp persist(conn, _old_name) do
    # 血刀剃度不改名，无需 NAME_D / Characters.rename_by_name，仅落盘 meta 变更。
    character = conn.private.update_character || conn.character

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      Records.save(character)
    end

    conn
  end
end
