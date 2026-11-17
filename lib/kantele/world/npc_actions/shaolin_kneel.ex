defmodule Kantele.World.NpcActions.ShaolinKneel do
  @moduledoc """
  少林剃度（`kneel`）—— LPC `kungfu/class/shaolin/qing-fa.c` 的 `do_kneel()`。

  **与 `Kantele.World.NpcActions.Kneel` 不是同一个 LPC 函数**：后者移植自
  `d/hangzhou/npc/qianlong.c do_kneel()`（跪乾隆、被踢下六和塔），本模块移植
  自清法比丘的受戒仪式。Player 必须先 `ask 清法 剃度`（见
  `Kantele.World.InquiryHandlers.Tonsure`）置 `pending/join_bonze`，再在本房间
  输入 `kneel` 才生效（LPC `if (!query_temp(...)) return 0;`）。

  ## LPC 原文逐条对应（`qing-fa.c:100-129`）

  1. `if (!me->query_temp("pending/join_bonze")) return 0;`
     → 未受请：`{:not_handled}`，交回全局命令（LPC 的 return 0）。
  2. `message_vision("$N双手合十…将$N的头发尽数剃去。", me, this_object())`
     → 房间广播；`$N`（行动者=玩家）交给 VisionView 渲染成「你」，`$n`（清法）
     替换为 NPC 名。
  3. `name = me->query("name"); new_name = prename[random(4)] + name[0..0];`
     `prename = ({ "虚", "空", "明", "净" })`
     → `Enum.random/1` 取姓，取玩家原名的第一个 grapheme 组成法名。
  4. `NAME_D->remove_name(...); me->set("name", new_name); NAME_D->map_name(...)`
     → 本端口无 NAME_D（见 `changeuser_command.ex` moduledoc），改为内存改名 +
     `ExVenture.Characters.rename_by_name/2` 改 DB 档案名。
  5. `command("say 从今以后你的法名叫做" + new_name + "。")` → NPC 公开说。
  6. `command("smile")` → LPC emote 无目标的旁观者文案「$N愉快地微笑着。」
     （data/emoted.o 的 smile 条目），以房间广播落地。
  7. `me->delete_temp("pending/join_bonze")` → `PlayerMeta.delete_temp/2`。
  8. `me->set("class", "bonze")` → `meta.family.class`（本端口 `query("class")`
     的统一映射，见 `family_event.ex`）。玩家尚无任何门派时建 `%{"class" => ...}`
     的裸 family map，不伪造门派名/师父 —— LPC 的 class 与 family 本就独立。
  9. `me->set("K_record", me->query("PKS") + me->query("MKS"))` → `meta.env[:K_record]`
     （LPC `set()` 属性统一仓库，落盘 `character_metadata.env`）。
  10. `me->set("shen_record", me->query("shen")); me->set("shen", 0)`
      → `meta.env[:shen_record]`（旧值）+ `meta.stats.shen = 0`。
  11. `return 1` → 返回更新后的 conn。

  ## 注册与安全

  只处理 `shaolin:guangchang1`（清法所在房间）且 **触发 NPC 确为清法比丘**
  的 `kneel`。registry 是房间级，同房间若有别的 NPC 也注册了 `kneel`，必须按
  NPC 身份过滤，否则会错误触发剃度。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias ExVenture.Characters
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.NameD
  alias Kantele.World.NpcActions.Helpers

  @room_id "shaolin:guangchang1"
  @npc_name "清法比丘"
  @pre_names ["虚", "空", "明", "净"]
  @pending_key :pending_join_bonze
  # LPC set_temp 的原 key（兼容由别的路径以字符串 key 写入的存档/测试）
  @pending_key_lpc "pending/join_bonze"

  @impl true
  def run(conn, %{room_id: room_id, npc: npc}) when is_binary(room_id) do
    if room_id == @room_id and qingfa?(npc) do
      do_kneel(conn, npc)
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp qingfa?(%{name: name, meta: %{aliases: aliases}}) when is_list(aliases) do
    name == @npc_name or
      Enum.any?(aliases, &(&1 in [@npc_name, "qingfa biqiu", "qingfa", "shaolin_qing_fa"]))
  end

  defp qingfa?(%{name: name}), do: name == @npc_name
  defp qingfa?(_), do: false

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
    npc_name = npc_name(npc)
    new_name = dharma_name(character.name)

    conn =
      conn
      |> Helpers.broadcast(
        @room_id,
        "$N双手合十，恭恭敬敬地跪了下来。\n\n" <>
          "#{npc_name}伸出手掌，在$N头顶轻轻地摩挲了几下，将$N的头发尽数剃去。\n\n"
      )
      |> Helpers.say(@room_id, npc_name, "从今以后你的法名叫做#{new_name}。")
      # LPC `command("smile")`：无目标 emote 的旁观者文案（data/emoted.o）。
      |> Helpers.broadcast(@room_id, "#{npc_name}愉快地微笑着。\n")

    updated = %{character | name: new_name, meta: tonsured_meta(meta)}

    conn
    |> put_character(updated)
    |> persist(character.name, new_name)
  end

  # LPC `prename[random(sizeof(prename))] + name[0..0]`
  defp dharma_name(name) when is_binary(name) do
    first = name |> String.graphemes() |> List.first() || "虚"
    Enum.random(@pre_names) <> first
  end

  defp dharma_name(_name), do: Enum.random(@pre_names) <> "虚"

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

    combat = Map.get(meta, :combat) || %{}
    pks = Map.get(combat, :PKS, 0) || 0
    mks = Map.get(combat, :MKS, 0) || 0
    old_shen = stats_shen(Map.get(meta, :stats)) || 0

    env =
      (Map.get(meta, :env) || %{})
      |> Map.put(:K_record, pks + mks)
      |> Map.put(:shen_record, old_shen)

    stats = put_shen(Map.get(meta, :stats), 0)

    meta
    |> Map.put(:temp, temp)
    |> Map.put(:family, family)
    |> Map.put(:env, env)
    |> Map.put(:stats, stats)
  end

  defp stats_shen(%{shen: shen}), do: shen
  defp stats_shen(_), do: 0

  defp put_shen(nil, value), do: %{shen: value}
  defp put_shen(%{} = stats, value), do: Map.put(stats, :shen, value)
  defp put_shen(_stats, value), do: %{shen: value}

  defp npc_name(%{name: name}) when is_binary(name) and byte_size(name) > 0, do: name
  defp npc_name(_npc), do: @npc_name

  # NAME-D 流程（LPC `NAME_D->remove_name/map_name` 等价）：
  #   1. NameD.remove_name(old_name, id)   释放俗家旧名
  #   2. NameD.change_name(old_name, id, new_name, false) 检查新法名是否冲突
  #   3. NameD.map_name(new_name, id)      登记新法名
  #   4. Characters.rename_by_name/2       同步落盘 DB 档案名
  # 若新名冲突（repeated），保留旧名、不改 DB，并在日志告警；
  # 测试 fixture（id=nil）跳过，避免沙盒噪音。
  defp persist(conn, old_name, new_name) do
    character = conn.private.update_character || conn.character

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      NameD.ensure!()

      NameD.remove_name(old_name, character.id)

      case NameD.change_name(old_name, character.id, new_name, false) do
        {:ok, _new_name} ->
          NameD.map_name(new_name, character.id)
          case Characters.rename_by_name(old_name, new_name) do
            {:ok, _} -> :ok
            {:error, :not_found} -> Logger.warn("name_d: 旧名 #{old_name} 未在 DB 中找到")
            {:error, :invalid} -> Logger.warn("name_d: 新名 #{new_name} 不合法或已被占用")
            {:error, :db_unavailable} -> Logger.warn("name_d: DB 不可用，#{old_name} 未落盘")
          end

        {:error, reason} ->
          Logger.warn("name_d: #{old_name} -> #{new_name} 被拒绝：#{reason}")
      end

      Records.save(character)
    end

    conn
  end
end
