defmodule Kantele.World.NpcActions.Kneel do
  @moduledoc """
  P5-1e NPC 私有动作：`kneel`（跪拜乾隆，LPC `d/hangzhou/npc/qianlong.c` 的
  `do_kneel()`）。

  仅注册于 `hangzhou:liuhe9`（六和塔顶，UCL `characters.qianlong` 经
  `room_characters "liuhe9"` 挂入；LPC 把弱玩家一脚踢下塔，故乾隆置于塔顶、
  落点取六和塔底 `liuheta`）。LPC 的 `do_kneel` 是 NPC 自身 `init` 注册的私有动词，
  本模块同样覆盖。

  ## 移植范围（LPC `do_kneel` 判定链）

  1. 陈家洛在场（`present("chen jialuo", environment(me))`）→ 广播「被陈家洛一把拦住」
     并 `chen->kill_ob(me)` 开打；**之后仍照常跪拜/判弱/封赏**（LPC 的 `if` 不 return）。
     陈家洛静态置于 city/fuzhou/quanzhou/kaifeng，六和塔顶常态无人在场，故本分支
     通常不触发；房间无进程时 `Room.npc_characters_by_id/1` 返回 `[]` 安全落空。
  2. `combat_exp < 150000` → 乾隆飞起一脚把玩家踢下六和塔（`me->move("/d/hangzhou/liuheta")`）、
     `receive_wound("qi", 20)`、扣 1% `combat_exp`（`add("combat_exp", -combat_exp/100)`），
     并广播「被踢下塔」文案。
  3. `marks/qianlong` 已置 → 「乾隆看着你，哼了一声，没理你」（LPC 不重复封赏）。
  4. 否则 → 置 `marks/qianlong = 1`、`add("combat_exp", 10000)`，乾隆道「免了！看在你
     救驾有功，免你死罪，朕自有封赏。」

  本模块落地 1/2/3/4 全链（含 `PlayerMeta.marks` 持久标记、`Stats.combat_exp` 增减、
  `Feature.Damage.receive_wound` 扣 qi、`hangzhou:liuheta` 简化位移、陈家洛在场
  `NpcAttack.kill_ob` 开战）。量词/文案逐字对齐 LPC。

  ## 已建模依赖

  - `me->query("combat_exp")` / `add` → `Kantele.Character.Stats.combat_exp`（`character.meta.stats`）。
  - `me->set("marks/qianlong", 1)` → `PlayerMeta.put_mark(meta, "qianlong", 1)`
    （落盘 `metadata.marks`，与 dugu_jiujian 读 `character.meta.marks` 同源）。
  - `me->receive_wound("qi", 20)` → `Kantele.Character.Feature.Damage.receive_wound/3`。
  - `me->move(...)` → 简化 `room_id` 更新（同 `drive_command.move_character` 的取径，
    不触发房间进出事件，作为本层迁移的等价简化）。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Feature.Damage
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.NpcActions.NpcAttack
  alias Kantele.World.Room

  @room_id "hangzhou:liuhe9"
  @npc_name "乾隆皇帝"
  @kicked_room_id "hangzhou:liuheta"
  @weak_exp_threshold 150_000

  @impl true
  def run(conn, %{room_id: room_id, npc: npc}) when is_binary(room_id) do
    if room_id == @room_id do
      do_kneel(conn, conn.character, npc)
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_kneel(conn, character, _npc) do
    meta = character.meta || %PlayerMeta{}
    stats = meta.stats || %Stats{}
    combat_exp = stats.combat_exp || 0

    # LPC 分支 1：陈家洛在场 → 拦住 + kill_ob（LPC 的 if 不 return，后续跪拜/判弱/封赏照常）
    conn = chen_attacks(conn, character)

    cond do
      # LPC 分支 2：exp < 150000 → 被踢下塔 + 扣血 + 扣 1% 经验
      combat_exp < @weak_exp_threshold ->
        kick_down_tower(conn, character, meta, stats)

      # LPC 分支 3：已封赏过 → 乾隆不理
      PlayerMeta.mark(meta, "qianlong") ->
        conn
        |> Helpers.broadcast(@room_id, "#{character.name}恭恭敬敬地跪了下来，却被#{@npc_name}一脚踢开。\n")
        |> then(&Helpers.render(&1, "#{@npc_name}看着你，哼了一声，没理你。\n"))

      # LPC 分支 4：封赏 → 置标记 + 经验
      true ->
        reward(conn, character, meta, stats)
    end
  end

  # LPC 分支 2：弱玩家被踢下六和塔
  #
  # 注意 `Damage.receive_wound/3` 返回 `{:ok, character}`（vitals 已扣），必须先解包
  # 再改 `room_id` / `stats`：直接把 tuple 当 struct 会崩溃，且会丢掉创伤后的 vitals。
  # `stats.combat_exp` 在弱分支可能是 nil（守卫用 `|| 0` 归一），故此处同样归一。
  defp kick_down_tower(conn, character, _meta, stats) do
    exp = stats.combat_exp || 0
    new_exp = exp - div(exp, 100)

    {:ok, wounded} = Damage.receive_wound(character, :qi, 20)

    conn =
      conn
      |> put_character(%{
        wounded
        | room_id: @kicked_room_id,
          meta: %{wounded.meta | stats: %{stats | combat_exp: new_exp}}
      })
      |> then(&Helpers.broadcast(&1, @room_id, "#{character.name}被#{@npc_name}一脚踢下了六和塔！\n"))
      |> then(&Helpers.render(&1, "你从塔顶被一脚踢了下来，好疼！还受了伤。\n"))

    persist(conn)
  end

  # LPC 分支 4：救驾有功封赏
  defp reward(conn, character, meta, stats) do
    conn =
      conn
      |> put_character(%{
        character
        | meta: %{meta | marks: Map.put(meta.marks || %{}, "qianlong", 1), stats: %{stats | combat_exp: stats.combat_exp + 10_000}}
      })
      |> then(&Helpers.broadcast(&1, @room_id, "#{character.name}恭恭敬敬地跪了下来，磕头道：奴才救驾来迟，皇上恕奴才死罪！\n"))
      |> then(&Helpers.render(&1, "你恭恭敬敬地跪了下来，磕头请安。\n"))
      |> then(&Helpers.say(&1, @room_id, @npc_name, "免了！看在你救驾有功，免你死罪，朕自有封赏。"))

    persist(conn)
  end

  # LPC 分支 1：陈家洛在场（`present("chen jialuo", environment(me))`）→ 拦住 + `kill_ob(me)`。
  # LPC 的 `if` 不 return，后续跪拜 `message_vision` 与弱玩家/封赏分支照常执行。
  # 房间无进程时 `Room.npc_characters_by_id/1` 返回 `[]`，本分支安全落空。
  defp chen_attacks(conn, character) do
    room_chars = Room.npc_characters_by_id(@room_id)
    chen = Enum.find(room_chars, &alias?(&1, "chen jialuo"))
    player = Enum.find(room_chars, &(Map.get(&1, :id) == character.id))

    if chen && player do
      conn
      |> Helpers.broadcast(
        @room_id,
        "#{character.name}正想给#{@npc_name}请安，却被陈家洛一把拦住：鞑子的鹰犬，不要脸的奴才，纳命来吧！\n"
      )
      |> then(fn c ->
        NpcAttack.kill_ob(chen, player)
        c
      end)
    else
      conn
    end
  end

  defp alias?(%{meta: %{aliases: aliases}}, id) when is_list(aliases), do: id in aliases
  defp alias?(_character, _id), do: false

  # 落盘 `marks` / `combat_exp`（`put_character/2` 只改内存态）。
  # 仅对真实玩家落盘：单测 fixture 的 `id` 为 nil，跳过可避免 `Records.save/1`
  # 因 `meta.combat`/`meta.vitals` 缺省而在沙盒里刷 error 日志。
  defp persist(conn) do
    character = conn.private.update_character || conn.character

    if is_binary(character.id) && String.starts_with?(character.id, "player:") do
      Records.save(character)
    end

    conn
  end
end
