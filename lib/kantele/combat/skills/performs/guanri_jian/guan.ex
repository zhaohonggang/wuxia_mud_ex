defmodule Kantele.Combat.Skills.Performs.GuanriJian.Guan do
  @moduledoc """
  perform「天洪地炉观日神诀」（source guanri-jian/guan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持剑 → 观日剑法>=280 →
  激发 `sword` 为观日剑法 → 内力上限>=5000 → 真气>=800 → 目标存活。
  攻击方无条件忙乱 3、扣 600 真气。起手广播后按 `ap/2 + random(ap) > 目标 force`
  判定：命中则目标 qi 伤 `damage`（`ap + random(ap)`）、qi 上限伤 `damage*150/100`，
  附加「烈炎剑气」；随后 `count = sword`，`apply/attack`/`apply/damage` 各 +count，
  连出 9 击，收招撤除加成。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., 150, (: final, …))` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*150/100)`；
    `final` 回调的 `affect_by("zhurong_jian", …)` 折算为
    `ConditionEvent.apply_poison/2`（`zhurong_jian.c` 的中文名为「烈炎剑气」）；
  - 9 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击 `ap/10`
    基础伤害 + `apply/damage` 加成 `count`，命中判定 `ap/2 + count`
    （`apply/attack` 加成）+ `random(ap)` vs 目标 `dodge`；加成/撤除折算进该判定
    与伤害，不写入 `combat.temp`（同 `daojian_guizhen/xue.ex`）；
  - 两处起手文案因显式 `+`（`weapon->name()` 两侧）被切成 2~3 段，
    E 侧用列表 `Enum.join("")` 保持同粒度（不得用 `<>` 合并相邻段）；
  - `.c` 的 `me->start_busy(3)`（无条件）与未命中分支的 `me->start_busy(2)`
    取最大值，故攻击方恒忙乱 3；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "guanri-jian/guan"
  @move_name "「天洪地炉观日神诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "sword")
    # LPC: damage = ap + random(ap);
    damage = ap + Engine.rand(rng, ap)
    lvl = Stats.skill(stats, "guanri-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("guanri-jian", 1) < 280)
  defp check_level(stats) do
    if Stats.skill(stats, "guanri-jian") < 280 do
      {:error, "你观日剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "guanri-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "guanri-jian" do
      {:error, "你没有激发观日剑法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 5000)
  #      if ((int)me->query("neili") < 800)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 ->
        {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}

      vitals.neili < 800 ->
        {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, weapon) do
    # LPC: msg = WHT "$N" WHT "施出观日剑法之「" HIW "天洪地炉观"
    #            HIR "日" HIW "神诀" NOR + WHT "」，将内力尽数注"
    #            "入" + weapon->name() + WHT "剑身直奔\n$n" WHT
    #            "而去。霎时间炽炎暴涨，热浪扑面卷来，四周空气便"
    #            "似沸腾一般。\n" NOR;
    #      me->start_busy(3); me->add("neili", -600);
    #      message_combatd(msg, me, target);
    # 三段固定文案被 `+` 分隔，逐段保留（勿用 `<>` 合并相邻段）。
    conn =
      Broadcast.publish(
        conn,
        Enum.join(
          [
            "$N施出观日剑法之「天洪地炉观日神诀",
            "」，将内力尽数注入",
            Map.get(weapon, :name),
            "剑身直奔\n$n而去。霎时间炽炎暴涨，热浪扑面卷来，四周空气便似沸腾一般。\n"
          ],
          ""
        ),
        n1: character.name,
        n2: target.name
      )

    # LPC: me->start_busy(3); me->add("neili", -600);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 600, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC: message_combatd(WHT "紧跟着$N" WHT "一声冷笑，身形蓦地前跃丈"
    #                     "许，手中" + weapon->name() + WHT "「唰唰唰」"
    #                     "连出九剑。\n" NOR, me, target);
    conn =
      Broadcast.publish(
        conn,
        Enum.join(
          [
            "紧跟着$N一声冷笑，身形蓦地前跃丈许，手中",
            Map.get(weapon, :name),
            "「唰唰唰」连出九剑。\n"
          ],
          ""
        ),
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage = Map.get(data, :damage, 0)
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force");
    #      if (ap / 2 + random(ap) > dp) { damage = ap + random(ap); … }
    hit = div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "force")

    # LPC hit:  msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 150,
    #                                      (: final, me, target, damage :));
    #           → receive_damage("qi", damage); receive_wound("qi", damage*150/100);
    vitals =
      if hit do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 150, 100))
      else
        character.meta.vitals
      end

    # LPC: count = me->query_skill("sword", 1);
    #      me->add_temp("apply/attack", count); me->add_temp("apply/damage", count);
    #      for (i = 0; i < 9; i++) { if (! me->is_fighting(target)) break;
    #                                COMBAT_D->do_attack(me, target, weapon, 0); }
    #      me->add_temp("apply/attack", -count); me->add_temp("apply/damage", -count);
    # 折算：每击 ap/10 基础伤害 + apply/damage 加成 count；
    #      命中判定 ap/2 + apply/attack 加成 count + random(ap) vs 目标 dodge。
    count = Stats.skill(stats, "sword")
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 10), 1)

    nine_damage =
      Enum.reduce(1..9, 0, fn _, acc ->
        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
          acc + per_hit + count + Engine.rand(rng, per_hit)
        else
          acc
        end
      end)

    vitals = Vitals.damage(vitals, :qi, nine_damage)
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC final(): target->affect_by("zhurong_jian",
    #   ([ "level" : lvl + random(lvl), "id" : me->query("id"),
    #      "duration" : lvl / 50 + random(lvl / 20) ]));
    conn =
      if hit do
        poison_level = lvl + Engine.rand(rng, lvl)
        poison_duration = div(lvl, 50) + Engine.rand(rng, div(lvl, 20))

        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "烈炎剑气"
        })
      else
        conn
      end

    # LPC: me->start_busy(3); me->add("neili", -600);（无条件，由攻击方侧结算）
    msg = if hit, do: final_message(), else: "可是$n看破了$N的企图，斜跃避开。\n"

    conn
    |> Broadcast.publish(msg, bindings)
    |> put_character(character)
  end

  # LPC final(): return HIR "只听$p" HIR "一声惨嚎，几柱鲜血射出，剑伤"
  #                     "处竟腾起一道烈火，烧得嗤嗤作响。\n" NOR;
  @doc false
  def final_message, do: "只听$p一声惨嚎，几柱鲜血射出，剑伤处竟腾起一道烈火，烧得嗤嗤作响。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define GUAN "「" HIW "天洪地炉观" HIR "日" HIW "神诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp, damage;
  #         int i, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/guanri-jian/guan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(GUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" GUAN "。\n");
  # 
  #         if ((int)me->query_skill("guanri-jian", 1) < 280)
  #                 return notify_fail("你观日剑法不够娴熟，难以施展" GUAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "guanri-jian")
  #                 return notify_fail("你没有激发观日剑法，难以施展" GUAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不够，难以施展" GUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 800)
  #                 return notify_fail("你现在的真气不足，难以施展" GUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "施出观日剑法之「" HIW "天洪地炉观"
  #               HIR "日" HIW "神诀" NOR + WHT "」，将内力尽数注"
  #               "入" + weapon->name() + WHT "剑身直奔\n$n" WHT
  #               "而去。霎时间炽炎暴涨，热浪扑面卷来，四周空气便"
  #               "似沸腾一般。\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  # 
  #         me->start_busy(3);
  #         me->add("neili", -600);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 150,
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 me->start_busy(2);
  #                 msg += CYN "可是$n" CYN "看破了$N" CYN "的企图，斜跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         count = me->query_skill("sword");
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/damage", count);
  # 
  #         message_combatd(WHT "紧跟着$N" WHT "一声冷笑，身形蓦地前跃丈"
  #                         "许，手中" + weapon->name() + WHT "「唰唰唰」"
  #                         "连出九剑。\n" NOR, me, target);
  # 
  #         for (i = 0; i < 9; i++)
  #           {
  #                    if (! me->is_fighting(target))
  #                            break;
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int lvl = me->query_skill("guanri-jian", 1);
  # 
  #         target->affect_by("zhurong_jian",
  #                 ([ "level"    : lvl + random(lvl),
  #                    "id"       : me->query("id"),
  #                    "duration" : lvl / 50 + random(lvl / 20) ]));
  # 
  #         return  HIR "只听$p" HIR "一声惨嚎，几柱鲜血射出，剑伤"
  #                 "处竟腾起一道烈火，烧得嗤嗤作响。\n" NOR;
  # }
end
