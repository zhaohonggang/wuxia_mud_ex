defmodule Kantele.World.NpcActions.EmeiKneel do
  @moduledoc """
  峨嵋派剃度（`kneel`）—— LPC `kungfu/class/emei/tobebonze.h` 的 `do_kneel()`。

  **与 `Kantele.World.NpcActions.ShaolinKneel` / `XueshanKneel` / `XuedaoKneel`
  不是同一个 LPC 函数**：本模块严格对应峨嵋九名师太共用的 `tobebonze.h`。
  玩家必须先向其中一名师太问「剃度/出家」（见
  `Kantele.World.InquiryHandlers.EmeiTonsure`）置 `pending/join_bonze`，
  再在该师太所在房间输入 `kneel` 才生效（LPC `if (!query_temp(...)) return 0;`）。

  ## LPC 原文逐条对应（`tobebonze.h` `do_kneel`）

  1. `if (!query_temp("pending/join_bonze")) return 0;`
     → 未受请：`:not_handled`，交回全局命令，不播任何文案。
  2. `message_vision("\\n$N你双手合十…随即便将$N的头发尽数剃去。", me, this_object())`
     → 按原文保留三段房间广播；`$N`（玩家）交给 `VisionView` 渲染成「你」，
     `$n`（NPC）在广播模板里写实际师太姓名。
  3. `name = me->query("purename"); if (!name) name = me->query("name");`
     → 优先取 `meta.env.purename`，无则取玩家当前姓名。
  4. `new_name = prename[random(sizeof(prename))] + name[0..0];`
     → `prename = ({ "灵", "文", "心", "妙" })`，取首字组成二字法名。
  5. `NAME_D->remove_name(me->query("name"), me->query("id"));
      me->set("name", new_name); NAME_D->map_name(...)`
     → 本端口无 NAME_D，按 `ShaolinKneel` 既有端口：释放旧名、检查重名、
     登记新名，并以 `Characters.rename_by_name/2` 同步 DB 档案名。
  6. `command("say 从今以后你的法名叫做" + new_name + "。")` → NPC 公开说。
  7. `command("nod")` → 无目标 emote 的旁观者文案「愉快地微笑着」。
  8. `me->set("marks/old_name", name)` → `meta.marks.old_name`（写 atom/string 双键，
     兼容加载后的 string-key map）。
  9. `me->delete_temp("pending/join_bonze")` → `PlayerMeta.delete_temp/2`。
  10. `me->set("class", "bonze")` → `meta.family.class`（保留既有门派字段）。
  11. `me->set("K_record", me->query("PKS") + me->query("MKS"))`
      → `meta.env[:K_record]`，PKS/MKS 取 `meta.combat.temp`。
  12. `me->set("shen_record", me->query("shen")); me->set("shen", 0)`
      → `meta.env[:shen_record]` 保存剃度前 shen，`meta.stats.shen = 0`。
  13. `return 1` → 返回更新后的 conn。

  ## 注册与安全

  九名师太各在自己房间；registry 是房间级，故按 room_id + NPC id/姓名/唯一别名
  双重校验。共用别名「shitai」不参与匹配，避免同房间其他师太误触发。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias ExVenture.Characters
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.NameD
  alias Kantele.World.NpcActions.Helpers

  @pending_key :pending_join_bonze
  @pending_key_lpc "pending/join_bonze"
  @pre_names ["灵", "文", "心", "妙"]

  # room_id => NPC 身份。id 同时列 clone_lib 定义 id 与运行态 npc- 前缀形态。
  @npcs %{
    "emei:fushouan" => %{
      name: "静真师太",
      ids: ["clone_lib:emei_zhen", "npc-emei_zhen"],
      aliases: ["emei_zhen", "jingzhen shitai", "jingzhen"]
    },
    "emei:hcaguangchang" => %{
      name: "静虚师太",
      ids: ["clone_lib:emei_xu", "npc-emei_xu"],
      aliases: ["emei_xu", "jingxu shitai", "jingxu"]
    },
    "emei:hcazhengdian" => %{
      name: "静心师太",
      ids: ["clone_lib:emei_xin", "npc-emei_xin"],
      aliases: ["emei_xin", "jingxin shitai", "jingxin"]
    },
    "emei:lingwenge" => %{
      name: "静照师太",
      ids: ["clone_lib:emei_zhao", "npc-emei_zhao"],
      aliases: ["emei_zhao", "jingzhao shitai", "jingzhao"]
    },
    "emei:qfadadian" => %{
      name: "静慧师太",
      ids: ["clone_lib:emei_hui", "npc-emei_hui"],
      aliases: ["emei_hui", "jinghui shitai", "jinghui"]
    },
    "emei:qingyinge" => %{
      name: "静闲师太",
      ids: ["clone_lib:emei_xian", "npc-emei_xian"],
      aliases: ["emei_xian", "jingxian shitai", "jingxian"]
    },
    "emei:wanxingan" => %{
      name: "静迦师太",
      ids: ["clone_lib:emei_jia", "npc-emei_jia"],
      aliases: ["emei_jia", "jingjia shitai", "jingjia"]
    },
    "emei:wnadian" => %{
      name: "静空师太",
      ids: ["clone_lib:emei_kong", "npc-emei_kong"],
      aliases: ["emei_kong", "jingkong shitai", "jingkong"]
    },
    "emei:woyunan" => %{
      name: "静玄师太",
      ids: ["clone_lib:emei_xuan", "npc-emei_xuan"],
      aliases: ["emei_xuan", "jingxuan shitai", "jingxuan"]
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

  defp matches_npc?(%{id: id, name: name, meta: %{aliases: aliases}}, info)
       when is_list(aliases) do
    id in info.ids or name == info.name or Enum.any?(aliases, &(&1 in info.aliases))
  end

  defp matches_npc?(%{id: id, name: name}, info), do: id in info.ids or name == info.name
  defp matches_npc?(_npc, _info), do: false

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
    do:
      truthy?(PlayerMeta.get_temp(meta, @pending_key)) or
        truthy?(PlayerMeta.get_temp(meta, @pending_key_lpc))

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_), do: true

  defp perform(conn, room_id, character, meta, npc_info) do
    npc_name = npc_info.name
    old_name = purename(character) || character.name
    new_name = dharma_name(old_name)

    conn =
      conn
      |> Helpers.broadcast(
        room_id,
        "\n$N你双手合十，恭恭敬敬地跪了下来。\n\n" <>
          "#{npc_name}看着$N说道：好吧，以后你就在本庵修行吧。\n\n" <>
          "#{npc_name}伸出手掌，在$N头顶轻轻地摩挲了几下，随即便将$N的头发尽数剃去。\n\n"
      )
      |> Helpers.say(room_id, npc_name, "从今以后你的法名叫做#{new_name}。")
      # LPC `command("nod")`：无目标 emote 的旁观者文案（data/emoted.o）。
      |> Helpers.broadcast(room_id, "#{npc_name}愉快地微笑着。\n")

    updated = %{character | name: new_name, meta: tonsured_meta(meta, old_name)}

    conn
    |> put_character(updated)
    |> persist(character.name, new_name)
  end

  # LPC `purename` 是独立于 name 的属性，落在统一 set() 仓库 meta.env。
  defp purename(character) do
    env = Map.get(character.meta || %{}, :env) || %{}
    Map.get(env, :purename) || Map.get(env, "purename")
  end

  # LPC `prename[random(sizeof(prename))] + name[0..0]`
  defp dharma_name(name) when is_binary(name) do
    first = name |> String.graphemes() |> List.first() || "灵"
    Enum.random(@pre_names) <> first
  end

  defp dharma_name(_name), do: Enum.random(@pre_names) <> "灵"

  defp tonsured_meta(meta, old_name) do
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
    combat_temp = Map.get(combat, :temp) || %{}
    pks = combat_number(combat_temp, :PKS) || combat_number(combat, :PKS)
    mks = combat_number(combat_temp, :MKS) || combat_number(combat, :MKS)
    old_shen = stats_shen(Map.get(meta, :stats)) || 0

    env =
      (Map.get(meta, :env) || %{})
      |> Map.put(:K_record, (pks || 0) + (mks || 0))
      |> Map.put(:shen_record, old_shen)

    marks =
      case Map.get(meta, :marks) do
        marks when is_map(marks) -> marks
        _ -> %{}
      end
      |> Map.put(:old_name, old_name)
      |> Map.put("old_name", old_name)

    meta
    |> Map.put(:temp, temp)
    |> Map.put(:family, family)
    |> Map.put(:env, env)
    |> Map.put(:marks, marks)
    |> Map.put(:stats, put_shen(Map.get(meta, :stats), 0))
  end

  defp combat_number(map, key) when is_map(map) do
    case Map.get(map, key) || Map.get(map, Atom.to_string(key)) do
      value when is_integer(value) -> value
      _ -> nil
    end
  end

  defp combat_number(_map, _key), do: nil

  defp stats_shen(%{shen: shen}), do: shen
  defp stats_shen(%{"shen" => shen}), do: shen
  defp stats_shen(_), do: 0

  defp put_shen(nil, value), do: %{shen: value}
  defp put_shen(%{} = stats, value), do: Map.put(stats, :shen, value)
  defp put_shen(_stats, value), do: %{shen: value}

  # 与 ShaolinKneel 同源的 NAME_D 流程：释放旧名 → 查重 → 登记新名 → DB 改名。
  # 测试 fixture（id=nil）跳过，避免沙盒/DB 噪音。
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
