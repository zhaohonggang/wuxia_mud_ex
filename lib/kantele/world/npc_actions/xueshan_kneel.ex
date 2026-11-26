defmodule Kantele.World.NpcActions.XueshanKneel do
  @moduledoc """
  大轮寺剃度（`kneel`）—— LPC `kungfu/class/xueshan/tobebonze.h` 的 `do_kneel()`。

  **与 `Kantele.World.NpcActions.ShaolinKneel` 不是同一个 LPC 函数**：后者移植自
  `kungfu/class/shaolin/qing-fa.c`（清法比丘，受戒改名/清 shen/置 K_record），
  本模块移植自 `tobebonze.h`（大轮寺 4 名 NPC，仅置 class=bonze/title，不改名、
  不清 shen、不置 K_record）。

  Player 必须先 `ask <NPC> 剃度`（见
  `Kantele.World.InquiryHandlers.XueshanTonsure`）置 `pending/join_bonze`，再在本房间
  输入 `kneel` 才生效（LPC `if (!query_temp(...)) return 0;`）。

  ## LPC 原文逐条对应（`tobebonze.h` `do_kneel`）

  1. `if (!query_temp("pending/join_bonze")) return 0;`
     → 未受请：`{:not_handled}`，交回全局命令（LPC 的 return 0）。
  2. `message_vision("$N双手合十，恭恭敬敬地跪了下来。…将$N的头发尽数剃去。", me, this_object())`
     → 房间广播；`$N`（行动者=玩家）交给 VisionView 渲染成「你」，`$n`（NPC）
     替换为 NPC 名。
  3. `set("class", "bonze")` → `meta.family.class`。玩家尚无任何门派时建
     `%{"class" => ...}` 的裸 family map，不伪造门派名/师父。
  4. `set("title", "大轮寺喇嘛")` → `meta.title`（LPC title 属性，落 `character_metadata.env`）。
  5. `command("nod")` → 房间广播 `${npc_name}愉快地微笑着。`（data/emoted.o 的 nod 条目）
  6. `command("say 既然出了家，就得一心向佛，再不能还俗。")` → NPC 公开说。
  7. `delete_temp("pending/join_bonze")` → `PlayerMeta.delete_temp/2`。
  8. `return 1` → 返回更新后的 conn。

  ## 与 ShaolinKneel 的差异（LPC tobebonze.h vs qing-fa.c）

  - 无改名：不调 Name_D / ExVenture.Characters.rename_by_name，玩家姓名保持不变。
  - 无 shen 清零：不置 `shen=0`，不置 `shen_record`/`K_record`。
  - 额外置 `title = "大轮寺喇嘛"`。
  - 性别守门由 inquiry 层完成（仅 male 可置 pending），kneel 层仅复核 pending。
  - 4 名 NPC 各在不同房间，按 room_id + NPC 身份双重校验：
    - gelunbu（葛伦布）→ xueshan:shanmen
    - jiamu（嘉木活佛）→ xueshan:cedian1
    - lazhang（拉章活佛）→ xueshan:dadian
    - samu（萨木活佛）→ xueshan:cedian2

  ## 注册与安全

  只处理上述 4 个房间且 **触发 NPC 确为对应大轮寺 NPC** 的 `kneel`。registry 是房间级，
  同房间若有别的 NPC 也注册了 `kneel`，必须按 NPC 身份过滤，否则会错误触发剃度。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.NpcActions.Helpers

  @pending_key :pending_join_bonze
  @pending_key_lpc "pending/join_bonze"

  # room_id => %{name: npc_name, aliases: [...]}
  @npcs %{
    "xueshan:shanmen" => %{
      name: "葛伦布",
      aliases: ["xueshan_gelunbu", "ge lunbu", "ge", "lunbu"]
    },
    "xueshan:cedian1" => %{
      name: "嘉木活佛",
      aliases: ["xueshan_jiamu", "jiamu huofo", "huofo", "jiamu"]
    },
    "xueshan:dadian" => %{
      name: "拉章活佛",
      aliases: ["xueshan_lazhang", "lazhang huofo", "lazhang", "huofo"]
    },
    "xueshan:cedian2" => %{
      name: "萨木活佛",
      aliases: ["xueshan_samu", "samu huofo", "huofo", "samu"]
    }
  }

  @impl true
  def run(conn, %{room_id: room_id, npc: npc}) when is_binary(room_id) do
    case Map.fetch(@npcs, room_id) do
      {:ok, npc_info} ->
        if matches_npc?(npc, npc_info) do
          do_kneel(conn, room_id, npc_info)
        else
          :not_handled
        end
      :error ->
        :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp matches_npc?(%{name: name, meta: %{aliases: aliases}}, info) when is_list(aliases) do
    name == info.name or Enum.any?(aliases, &(&1 in info.aliases))
  end

  defp matches_npc?(%{name: name}, _info), do: false
  defp matches_npc?(_), do: false

  defp do_kneel(conn, room_id, npc_info) do
    character = conn.private.update_character || conn.character
    meta = character.meta || %PlayerMeta{}

    if pending?(meta) do
      perform(conn, room_id, character, meta, npc_info)
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

  defp perform(conn, room_id, character, meta, npc_info) do
    npc_name = npc_info.name

    conn =
      conn
      |> Helpers.broadcast(
        room_id,
        "$N双手合十，恭恭敬敬地跪了下来。\n\n" <>
          "#{npc_name}伸出手掌，在$N头顶轻轻地摩挲了几下，将$N的头发尽数剃去。\n\n"
      )
      |> Helpers.say(room_id, npc_name, "既然出了家，就得一心向佛，再不能还俗。")
      # LPC `command("nod")`：无目标 emote 的旁观者文案（data/emoted.o）。
      |> Helpers.broadcast(room_id, "#{npc_name}愉快地微笑着。\n")

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
    |> Map.put(:title, "大轮寺喇嘛")
  end

  defp persist(conn, _old_name) do
    # 大轮寺剃度不改名，无需 NAME_D / Characters.rename_by_name，仅落盘 meta 变更。
    character = conn.private.update_character || conn.character

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      Records.save(character)
    end

    conn
  end
end
