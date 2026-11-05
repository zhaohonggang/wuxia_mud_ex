defmodule Kantele.Character.AnsuanCommand do
  @moduledoc """
  暗算命令：`ansuan <人物> at <方向>`

  对应 LPC `cmds/std/ansuan.c`。隔着一条出口扑向相邻房间的目标，打一记冷不防的
  偷袭，再按双方阅历决定是否露出行藏。

  ## 移植范围（LPC 门控逐条落地）

  1. `is_chatter()` / 参数 `sscanf("%s at %s")` 格式门；
  2. `default_where` 方向别名归一（n/s/e/w/nu/… /ne/nw/se/sw/u/d）；
  3. 当前房间 `exits` 里必须有该方向；
  4. 目标房间 `no_fight`；
  5. `present(who, 目标房间)` 找人、`is_character()`、`query_competitor()`；
  6. `is_busy()` / `query("doing")` / `is_fighting()`；
  7. `query("can_speak")` / `living(target)` / `query("jing", 1) >= 100`；
  8. `valid_leave(me, where)`（本端口走 `Kantele.World.exit_veto_message/2` 回查
     房间 `exit_vetoes` 的 `notify_fail` 原文）；
  9. `accept_ansuan(me)`（玩家/守卫接受，fighter 类 NPC 拒绝）；
  10. `default_dirs` / `default_undirs` 方向中文、`gender == "女性"` → 倩影/人影；
  11. 突袭判定 `random(me.exp) > target.exp/2 && !is_guarder()`：成功让目标
      `start_busy(random(4)+2)`，失败则目标立刻反击一记；
  12. 暴露判定 `random(me.exp) < target.exp/5 || is_guarder()`：暴露则身份揭穿、
      双方结仇开战；未暴露则悄然退回原处；
  13. 收尾 `start_busy(3)` + `receive_damage("jing", 50)`。

  ## 与 LPC 的差异（引擎模型所限，均已在文案/行为上对齐）

  - **不做「瞬移过去再瞬移回来」**：LPC 用 `move(environment(target))` 把暗算者
    真正搬进目标房间打一下，再 `move(old_env)` 退回。本引擎的心跳战斗是
    「双方必须同房间」的（见 `CombatEvent` 的 `combat/tick` 同房间校验），
    冷不防的一击改用 `NpcAttack.strike/2` 的 `combat/incoming` 跨房间结算；
    **只有暴露分支**才用 `Teleport.teleport/2` 把暗算者搬进目标房间并
    `NpcAttack.kill_ob/2` 起持久战斗，未暴露分支留在原地（等价 LPC 的
    「立刻退回原处」）。
  - **蒙面 `apply/name` 等四个 temp 字段不建模**：本引擎没有 LPC 的
    `set_temp("apply/...")` 别名机制，改用 vision 文案里的「一条人影／倩影」
    表达同一效果（目标在暴露分支才看到真名）。
  - **`want_kill(target)`**：在暴露分支由 `NpcAttack.kill_ob/2` 的
    `combat/start type: "kill"` 承担；未暴露分支不结仇（与 LPC 一致：LPC 只在
    暴露分支 `kill_ob`/`fight_ob`）。
  - **`add_temp("str", count)` 的命中加成**：本引擎的 `Fighter` 快照在 `strike/2`
    里现算，没有可跨进程注入的临时属性，故省略；突袭的收益由「目标 busy」体现。
  - **`COMBAT_D->do_attack` 的武器/招式**：走 `combat/incoming`，由目标进程以
    其完整状态结算，和 `touxi`/NPC 主动出手同一条链路。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Teleport
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.NpcAttack
  alias Kantele.World.Room

  # LPC default_where：短别名 → 出口名
  @where_aliases %{
    "n" => "north",
    "s" => "south",
    "e" => "east",
    "w" => "west",
    "nu" => "northup",
    "su" => "southup",
    "eu" => "eastup",
    "wu" => "westup",
    "nd" => "northdown",
    "sd" => "southdown",
    "ed" => "eastdown",
    "wd" => "westdown",
    "ne" => "northeast",
    "nw" => "northwest",
    "se" => "southeast",
    "sw" => "southwest",
    "u" => "up",
    "d" => "down"
  }

  # LPC default_dirs：出口名 → 中文去向
  @dirs %{
    "north" => "北边",
    "south" => "南边",
    "east" => "东边",
    "west" => "西边",
    "northup" => "北边",
    "southup" => "南边",
    "eastup" => "东边",
    "westup" => "西边",
    "northdown" => "北边",
    "southdown" => "南边",
    "eastdown" => "东边",
    "westdown" => "西边",
    "northeast" => "东北",
    "northwest" => "西北",
    "southeast" => "东南",
    "southwest" => "西南",
    "up" => "上面",
    "down" => "下面",
    "enter" => "里面",
    "in" => "里面",
    "out" => "外面"
  }

  # LPC default_undirs：出口名 → 中文来向（目标视角）
  @undirs %{
    "south" => "北边",
    "north" => "南边",
    "west" => "东边",
    "east" => "西边",
    "southup" => "北边",
    "northup" => "南边",
    "westup" => "东边",
    "eastup" => "西边",
    "southdown" => "北边",
    "northdown" => "南边",
    "westdown" => "东边",
    "eastdown" => "西边",
    "southwest" => "东北",
    "southeast" => "西北",
    "northwest" => "东南",
    "northeast" => "西南",
    "down" => "上面",
    "up" => "下面",
    "out" => "里面",
    "in" => "外面",
    "enter" => "外面"
  }

  @doc """
  解析 `ansuan <人物> at <方向>`。

  LPC 的 `sscanf(arg, "%s at %s", who, where_temp)` 只接受两个以空白分隔的词，
  故这里同样不允许方向/人物里带空格。方向大小写不敏感（LPC 的 mapping 键是小写）。
  """
  def parse(rest) when is_binary(rest) do
    case Regex.run(~r/^\s*(\S+)\s+at\s+(\S+)\s*$/, rest) do
      [_, who, where] -> {:ok, who, String.downcase(where)}
      _ -> {:error, :format}
    end
  end

  def parse(_), do: {:error, :format}

  @doc "LPC `default_where`：短别名归一为出口名，未登记的按原样透传。"
  def normalize_direction(where), do: Map.get(@where_aliases, where, where)

  @doc "LPC `default_dirs`：去向中文。"
  def direction_name(where), do: Map.get(@dirs, where, where)

  @doc "LPC `default_undirs`：来向中文（目标视角）。"
  def opposite_name(where), do: Map.get(@undirs, where, where)

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    case parse(rest) do
      {:error, :format} -> usage(conn)
      {:ok, who, where_arg} -> attempt(conn, who, normalize_direction(where_arg))
    end
  end

  def run(conn, %{}), do: usage(conn)

  defp attempt(conn, who, where) do
    me = conn.character

    case exit_room(exits_of(snapshot(conn, me.room_id)), where) do
      nil ->
        reject(conn, "没有这个方向。\n")

      target_room_id ->
        adjudicate(conn, me, who, where, target_room_id)
    end
  end

  defp adjudicate(conn, me, who, where, target_room_id) do
    target =
      characters_of(snapshot(conn, target_room_id))
      |> Enum.find(fn character ->
        character.pid != me.pid and Room.NameMatch.matches?(character, who)
      end)

    cond do
      "no_fight" in room_flags(conn, target_room_id) ->
        reject(conn, "那里禁止战斗。\n")

      is_nil(target) ->
        reject(conn, "这个方向没有此人。\n")

      not is_character?(target) ->
        reject(conn, "看清楚一点，那并不是生物。\n")

      competitor?(target) ->
        reject(conn, "人家正在和别人比武，你要是暗算人家也未免太无耻了吧？\n")

      busy?(me) or Map.get(me.attributes || %{}, "doing") ->
        reject(conn, "你的动作还没有完成，不能暗算别人。\n")

      fighting?(me) ->
        reject(conn, "你正忙着战斗呢，还有心思暗算别人？\n")

      not can_speak?(target) ->
        reject(conn, "你这人真有意思，连#{target.name}也想暗算。\n")

      dead?(target) ->
        reject(conn, "#{target.name}都已经这样了，你还用得着暗算吗？\n")

      jing(me) < 100 ->
        reject(conn, "你无法集中精力，暗算不了别人。\n")

      veto = veto_message(conn, me.room_id, where) ->
        reject(conn, to_string(veto))

      not accepts_ansuan?(target) ->
        reject(conn, "一个#{target.name}有什么好暗算的？\n")

      true ->
        execute(conn, me, target, where, target_room_id)
    end
  end

  # ---- 暗算执行（LPC main 后半段） ----

  defp execute(conn, me, target, where, target_room_id) do
    dir = direction_name(where)
    undir = opposite_name(where)
    gen = if gender(me) == "女性", do: "倩影", else: "人影"
    guarder? = guarder?(target)

    my_exp = max(1, combat_exp(me))
    target_exp = combat_exp(target)

    # 第一次突袭（LPC COMBAT_D->do_attack(me, target, weapon)）
    safe_strike(me, target)

    surprise? = roll(my_exp) > div(target_exp, 2) and not guarder?

    if surprise? do
      tell(target, "\n一条#{gen}忽然从#{undir}向你扑来！\n\n")
      broadcast(target_room_id, "\n一条#{gen}忽然从#{undir}向#{target.name}扑来！\n\n", target.pid)
      tell(me, "\n#{target.name}一时没有防范，被你攻了个措手不及！\n")
    else
      tell(target, "\n一条#{gen}忽然从#{undir}向你扑来！\n\n")
      broadcast(target_room_id, "\n一条#{gen}忽然从#{undir}向#{target.name}扑来！\n\n", target.pid)
      tell(me, "\n#{target.name}经验丰富，不及细看，立刻向你反击！\n")
      safe_strike(target, me)
    end

    revealed? = roll(my_exp) < div(target_exp, 5) or guarder?

    opening =
      "你摒息静气，纵身而起，向#{dir}的#{target.name}扑去！\n" <>
        "\n一条#{gen}忽然从#{undir}向#{target.name}扑来！\n\n"

    broadcast(me.room_id, "\n一条#{gen}忽然向#{dir}扑去，转眼间又回到原处！\n\n", me.pid)

    {conn, closing} =
      if revealed? do
        # LPC：暴露后 target->kill_ob(me)/fight_ob(me)，暗算者留在目标房间继续打
        NpcAttack.kill_ob(me, target)
        conn = Teleport.teleport(conn, target_room_id)

        {conn,
         "不好，被#{target.name}发觉了！\n" <>
           "#{target.name}喝道：#{me.name}！你敢暗算我，我跟你没完！\n"}
      else
        # LPC：人影转瞬不见 + me->move(old_env)，本端口本来就「瞬移过去又回来」，
        # 冷不防一击已由 combat/incoming 跨房间结算，故原地不动即等价。
        broadcast(target_room_id, "\n#{gen}转瞬不见！\n\n", me.pid)
        tell(target, "你一定神，可是什么都没看见。\n")

        {conn,
         "你立刻退回原处！\n" <>
           "哈哈，#{target.name}居然没看出来。\n你搓了搓手，一脸无辜的样子。\n"}
      end

    conn
    |> put_character(exhaust(conn, me))
    |> render(CommandView, "text", %{text: opening <> closing})
    |> prompt(CommandView, "prompt", %{})
  end

  # LPC 收尾：me->start_busy(3); me->receive_damage("jing", 50)
  # 注意：Teleport 可能已改写 conn.private.update_character，取最新角色再叠加。
  defp exhaust(conn, me) do
    character = Map.get(conn.private, :update_character) || conn.character || me
    meta = character.meta

    combat = Combat.start_busy(meta.combat || Combat.new(), 3)
    vitals = Vitals.damage(meta.vitals || Vitals.new(), :jing, 50)

    new_meta = %{meta | combat: combat, vitals: vitals}
    %{character | meta: new_meta}
  end

  defp safe_strike(attacker, target) do
    NpcAttack.strike(attacker, target)
    :ok
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  # ---- 消息原语 ----

  defp tell(%{pid: pid}, text) when is_pid(pid), do: send(pid, {:room_message, text})
  defp tell(_, _text), do: :ok

  defp broadcast(room_id, text, except_pid) do
    Room.tell_room(%Room{id: room_id}, text, except_pid)
    :ok
  rescue
    _ -> :ok
  end

  # ---- 世界数据查询（单测可从 conn.private 注入，避免依赖 ZoneCache / 房间进程） ----

  defp room_flags(conn, room_id) do
    case Map.get(conn.private, :room_flags) do
      fun when is_function(fun, 1) -> fun.(room_id)
      flags when is_list(flags) -> flags
      _ -> Kantele.World.room_flags(room_id)
    end
  end

  defp veto_message(conn, room_id, where) do
    case Map.get(conn.private, :exit_vetoes) do
      fun when is_function(fun, 2) -> fun.(room_id, where)
      map when is_map(map) -> Map.get(map, {room_id, where}) || Map.get(map, where)
      _ -> Kantele.World.exit_veto_message(room_id, where)
    end
  end

  # ---- 房间快照（单测可从 conn.private 注入，避免起真房间进程） ----

  defp snapshot(conn, room_id) do
    private = conn.private || %{}

    cond do
      room_id == conn.character.room_id and is_map(Map.get(private, :room)) ->
        Map.get(private, :room)

      is_map(Map.get(Map.get(private, :rooms, %{}) || %{}, room_id)) ->
        Map.get(Map.get(private, :rooms, %{}), room_id)

      true ->
        Room.snapshot(room_id)
    end
  end

  defp exits_of(snapshot) when is_map(snapshot) do
    get_in(snapshot, [:attrs, "exits"]) ||
      Map.get(snapshot, :exits) ||
      Map.get(snapshot, "exits") ||
      %{}
  end

  defp exits_of(_), do: %{}

  defp exit_room(exits, where) when is_map(exits) do
    Enum.find_value(exits, fn {key, value} ->
      if to_string(key) == where, do: value
    end)
  end

  defp exit_room(_, _where), do: nil

  defp characters_of(%{private: %{characters: characters}}) when is_list(characters),
    do: characters

  defp characters_of(%{characters: characters}) when is_list(characters), do: characters
  defp characters_of(_), do: []

  # ---- LPC 判定 ----

  defp is_character?(character), do: Map.has_key?(character, :name)

  defp competitor?(%{meta: meta}) when is_map(meta) do
    flat = Map.get(meta, :attack_competitor)
    nested = case Map.get(meta, :attack) do
      %{competitor: value} -> value
      _ -> nil
    end

    not is_nil(flat) or not is_nil(nested)
  end

  defp competitor?(_), do: false

  defp busy?(character) do
    combat = Map.get(character.meta || %{}, :combat) || Combat.new()
    Combat.busy?(combat)
  end

  defp fighting?(character) do
    combat = Map.get(character.meta || %{}, :combat) || Combat.new()
    Combat.fighting?(combat)
  end

  # LPC `query("can_speak")` 与 `living(target)` 是**两道独立的门**：前者拦的是
  # 物品/摆设（它们没有 can_speak），后者拦尸体。房间快照的 `characters` 列表
  # 里本来就只有角色，故这里只在显式标了 false 时才拦，否则普通 NPC 会被误拒。
  defp can_speak?(target) do
    attrs = target.attributes || %{}
    meta = target.meta || %{}

    not (attrs["can_speak"] == false or
           Map.get(meta, "can_speak") == false or
           Map.get(meta, :can_speak) == false)
  end

  defp dead?(target) do
    attrs = target.attributes || %{}
    status = Map.get(target, :status)

    attrs["ghost"] == true or
      Map.get(attrs, "not_living") == true or
      (is_binary(status) and String.contains?(status, "尸体"))
  end

  defp jing(character) do
    vitals = Map.get(character.meta || %{}, :vitals)
    value = if vitals, do: Map.get(vitals, :jing), else: nil
    value || Map.get(character.attributes || %{}, "jing") || 0
  end

  defp combat_exp(character) do
    stats = Map.get(character.meta || %{}, :stats)
    (stats && Map.get(stats, :combat_exp)) || 0
  end

  defp gender(character) do
    env = Map.get(character.meta || %{}, :env) || %{}
    Map.get(env, :gender) || Map.get(env, "gender") || "男性"
  end

  defp guarder?(%{meta: meta}) when is_map(meta), do: not is_nil(Map.get(meta, :guarder))
  defp guarder?(_), do: false

  # LPC random(n) ∈ [0, n-1]；这里用 1..n，阈值比较不受影响
  defp roll(n) when is_integer(n) and n > 0, do: :rand.uniform(n)
  defp roll(_), do: 0

  # LPC accept_ansuan：clone/user/user.c（玩家）与 npc.c（守卫分支）接受；
  # inherit/char/fighter.c 覆盖为「一个X有什么好暗算的？」拒绝。
  defp accepts_ansuan?(%{meta: %PlayerMeta{}}), do: true

  defp accepts_ansuan?(%{meta: meta}) when is_map(meta) do
    not is_nil(Map.get(meta, :guarder)) or is_nil(Map.get(meta, :combat_config))
  end

  defp accepts_ansuan?(_), do: false

  # ---- 输出 ----

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：ansuan <人物> at <方向>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
