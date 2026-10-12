defmodule Kantele.Combat.Skills.Performs.Hamagong.Zhen do
  @moduledoc """
  perform「蟾震九天」（source hamagong/perform/zhen.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：已学此招 → 目标在战斗中 → 蛤蟆功>=240 →
  内力上限>=4000 → 真气>=800 → 掌法>=200 → 空手 →
  激发且准备 `strike` 为蛤蟆功 → 目标存活。
  三段掌击（起手文案各自先行广播），每段以
  `ap*2/3`、`ap*3/5`、`ap*11/20`（`ap = force`）加 `random(ap)` 对
  `dp = (目标 force + parry + dodge + 一阳指)/3` 判定；命中则累计
  `random(damage/2)`（第三段为 `random(damage)`）并造成
  qi 伤与 `50/60/70 + random(蛤蟆功/30)`% 的 qi 上限伤。
  最后攻击方忙乱 `3+random(4)`、扣 `400+random(400)` 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., UNARMED_ATTACK, damage, N, 文案)` 折算为
    目标侧 `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*N/100)`；
  - `.c` 在攻击方连续 `message_combatd` 三段起手文案、其间穿插 `do_damage`；
    引擎由攻击方 `apply_effect/4` 一次广播三段起手，三段伤害在目标侧
    `resolve_incoming/4` 依次结算（顺序与 `.c` 一致，仅广播时机略有提前）；
  - `.c` 的 `me->query_temp("reverse")` 全库无 `set_temp("reverse")` 写入点
    （死分支），故 `hamagong_effect` 恒取 `蛤蟆功/30`；
  - `damage`/`hamagong_effect` 为 0 时 LPC `random(0)` 恒返回 0，此处以
    `max(..., 1)` 兜底（`ap = force >= 1`，实际不可达）；
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
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "hamagong/zhen"
  @move_name "「蟾震九天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("force"); skill = me->query_skill("hamagong", 1);
    #      poison = me->query_skill("poison", 1);
    ap = Stats.skill(stats, "force")
    skill = Stats.skill(stats, "hamagong")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          skill: skill,
          poison: Stats.skill(stats, "poison"),
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
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
      [] -> {:error, "蛤蟆功#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: skill = me->query_skill("hamagong", 1); if (skill < 240)
  #        return notify_fail("你的蛤蟆功修为不够精深，不能使用" ZHEN "！\n");
  #      if (me->query_skill("strike") < 200)
  #        return notify_fail("你的掌法不够娴熟，无法施展" ZHEN "！\n");
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "hamagong") < 240 ->
        {:error, "你的蛤蟆功修为不够精深，不能使用#{@move_name}！\n"}

      Stats.skill(stats, "strike") < 200 ->
        {:error, "你的掌法不够娴熟，无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("max_neili") < 4000)
  #        return notify_fail("你的内力修为不够深厚，无法施展" ZHEN "！\n");
  #      if (me->query("neili") < 800)
  #        return notify_fail("你的真气不够，无法运用" ZHEN "！\n");
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "你的内力修为不够深厚，无法施展#{@move_name}！\n"}
      vitals.neili < 800 -> {:error, "你的真气不够，无法运用#{@move_name}！\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_temp("weapon"))
  #        return notify_fail("你必须空手才能使用" ZHEN "！\n");
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手才能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "hamagong" ||
  #         me->query_skill_mapped("strike") != "hamagong")
  #        return notify_fail("你必须先将蛤蟆功运用于掌法之中，才能运用" ZHEN "。\n");
  defp check_mapped(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    prepared_ok =
      is_binary(prepared) and prepared |> String.split("/") |> hd() == "hamagong"

    if prepared_ok and Stats.mapped(stats, "strike") == "hamagong" do
      :ok
    else
      {:error, "你必须先将蛤蟆功运用于掌法之中，才能运用#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, rng) do
    bindings = [n1: character.name, n2: target.name]

    # LPC: msg = HIB "$N身子蹲下，左掌平推而出，使的正是$N生平最得意的「蟾震九天」绝招，掌风直逼$n而去！\n" NOR;
    #      msg = HIB "$N左掌劲力未消，右掌也跟着推出，功力相叠，" ZHEN "掌风排山倒海般涌向$n！\n"NOR;
    #      msg = HIB "$N双腿一蹬，双掌相并向前猛力推出，$n连同身前方圆三丈全在" ZHEN "劲力笼罩之下！\n"NOR;
    conn =
      conn
      |> Broadcast.publish(
        "$N身子蹲下，左掌平推而出，使的正是$N生平最得意的#{@move_name}绝招，掌风直逼$n而去！\n",
        bindings
      )
      |> Broadcast.publish(
        "$N左掌劲力未消，右掌也跟着推出，功力相叠，#{@move_name}掌风排山倒海般涌向$n！\n",
        bindings
      )
      |> Broadcast.publish(
        "$N双腿一蹬，双掌相并向前猛力推出，$n连同身前方圆三丈全在#{@move_name}劲力笼罩之下！\n",
        bindings
      )

    # LPC: me->start_busy(3 + random(4)); me->add("neili", -400 - random(400));
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - (400 + Engine.rand(rng, 400)), 0)}
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

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
    skill = Map.get(data, :skill, 0)
    poison = Map.get(data, :poison, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = (target->query_skill("force") + target->query_skill("parry") +
    #            target->query_skill("dodge") + target->query_skill("yiyang-zhi")) / 3;
    dp =
      div(
        Stats.skill(stats, "force") + Stats.skill(stats, "parry") +
          Stats.skill(stats, "dodge") + Stats.skill(stats, "yiyang-zhi"),
        3
      )

    # LPC: damage = ap; if (skill > 500) damage += poison; else damage += poison * skill / 500;
    base =
      if skill > 500, do: ap + poison, else: ap + div(poison * skill, 500)

    # LPC: if (me->query_temp("reverse")) hamagong_effect = skill / 20;
    #      else hamagong_effect = skill / 30;   —— reverse 全库无写入点，恒取 /30
    he = max(div(skill, 30), 1)

    # 三段掌击：`ap * 2 / 3` / `ap * 3 / 5` / `ap * 11 / 20`；命中累计
    # `random(damage / 2)`（第三段 `random(damage)`），并造成
    # `50 / 60 / 70 + random(he)` % 的 qi 上限伤。
    stages = [
      %{
        num: 2,
        den: 3,
        wound: 50,
        inc_div: 2,
        hit: "$n不料$N会使出如此诡异招式，慌忙伸掌抵挡，结果$N蛤蟆功内劲不断袭入，$n全身顿时感到一阵撕裂般的痛苦。\n",
        miss: "可是$n发觉一股微风扑面而来，却已被逼得呼吸不畅，情知不妙，连忙跃开数尺。\n"
      },
      %{
        num: 3,
        den: 5,
        wound: 60,
        inc_div: 2,
        hit: "$n只觉此招，阴柔无比，诡异莫测，心中一惊，却猛然间觉得一股阴风透骨而过。\n",
        miss: "$n喘息未定，又觉一股劲风扑面而来，连忙跃开数尺，狼狈地避开。\n"
      },
      %{
        num: 11,
        den: 20,
        wound: 70,
        inc_div: 1,
        hit: "$n全然无力阻挡，竟被$N双掌击得飞起，重重的跌落在地上。\n",
        miss: "$n用尽全身力量向右一纵一滚，摇摇欲倒地站了起来，但总算躲开了这致命的一击！\n"
      }
    ]

    {conn, character, _damage} =
      Enum.reduce(stages, {conn, character, base}, fn stage, {conn, character, damage} ->
        if div(ap * stage.num, stage.den) + Engine.rand(rng, ap) > dp do
          damage = damage + Engine.rand(rng, max(div(damage, stage.inc_div), 1))
          wound = div(damage * (stage.wound + Engine.rand(rng, he)), 100)

          vitals =
            character.meta.vitals
            |> Vitals.damage(:qi, damage)
            |> Vitals.wound(:qi, wound)

          character = %{character | meta: %{character.meta | vitals: vitals}}
          {Broadcast.publish(conn, stage.hit, bindings), character, damage}
        else
          {Broadcast.publish(conn, stage.miss, bindings), character, damage}
        end
      end)

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" HIW "蟾震九天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int skill, ap, dp, damage, poison, hamagong_effect;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("蛤蟆功" ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         skill = me->query_skill("hamagong", 1);
  #         poison = me->query_skill("poison", 1);
  # 
  #         if (skill < 240)
  #                 return notify_fail("你的蛤蟆功修为不够精深，不能使用" ZHEN "！\n");
  # 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不够深厚，无法施展" ZHEN "！\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你的真气不够，无法运用" ZHEN "！\n");
  # 
  #         if (me->query_skill("strike") < 200)
  #                 return notify_fail("你的掌法不够娴熟，无法施展" ZHEN "！\n");
  # 
  #         if( me->query_temp("weapon") )
  #                 return notify_fail("你必须空手才能使用" ZHEN "！\n");
  # 
  #         if (me->query_skill_prepared("strike") != "hamagong" ||
  #             me->query_skill_mapped("strike") != "hamagong")
  #                 return notify_fail("你必须先将蛤蟆功运用于掌法之中，才能运用" ZHEN "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "$N身子蹲下，左掌平推而出，使的正是$N生平最得意的「蟾震九天」绝招，掌风直逼$n而去！\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         ap = me->query_skill("force");
  #         dp = (target->query_skill("force") + target->query_skill("parry") + target->query_skill("dodge") + target->query_skill("yiyang-zhi") ) / 3;
  # 
  #         damage = ap;
  # 
  #         if(skill > 500)
  #             damage += poison;
  #         else
  #             damage += poison * skill / 500;
  # 
  #         if(me->query_temp("reverse"))
  #                 hamagong_effect = (int)(skill / 20);
  #         else
  #                 hamagong_effect = (int)(skill / 30);
  # 
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 damage += random(damage / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50 + random(hamagong_effect),
  #                                            HIR "$n" HIR "不料$N会使出如此诡异招式，慌忙伸掌抵挡，"
  #                                                "结果$N蛤蟆功内劲不断袭入，$n全身顿时感到一阵撕裂般的痛苦。\n" NOR);
  #         }else
  #         {
  #                 msg = HIY "可是$n发觉一股微风扑面而来，却已被逼得呼吸不畅，情知不妙，连忙跃开数尺。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         msg = HIB "$N左掌劲力未消，右掌也跟着推出，功力相叠，" ZHEN "掌风排山倒海般涌向$n！\n"NOR;
  #         message_combatd(msg, me, target);
  # 
  #         if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #                 damage += random(damage / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60 + random(hamagong_effect),
  #                                            HIR "$n" HIR "只觉此招，阴柔无比，诡异莫测，"
  #                                                "心中一惊，却猛然间觉得一股阴风透骨而过。\n" NOR);
  #         }else
  #         {
  #                 msg = HIY "$n喘息未定，又觉一股劲风扑面而来，连忙跃开数尺，狼狈地避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         msg = HIB "$N双腿一蹬，双掌相并向前猛力推出，$n连同身前方圆三丈全在" ZHEN "劲力笼罩之下！\n"NOR;
  #         message_combatd(msg, me, target);
  # 
  #          if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 damage += random(damage);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(hamagong_effect),
  #                                            HIR "$n" HIR "全然无力阻挡，竟被$N" HIY "双掌击得飞起，重重的跌落在地上。\n" NOR);
  #         }else
  #         {
  #                 msg = HIY "$n用尽全身力量向右一纵一滚，摇摇欲倒地站了起来，但总算躲开了这致命的一击！\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->start_busy(3 + random(4));
  #         me->add("neili", -400 - random(400));
  # 
  #         return 1;
  # }
end
