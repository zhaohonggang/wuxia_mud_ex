defmodule Kantele.Combat.Skills.Performs.JiuyinBaiguzhao.Zhua do
  @moduledoc """
  perform「九阴神爪」（source jiuyin-baiguzhao/zhua.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阴白骨爪>=120 → 准备 claw 为九阴白骨爪 → 内力>=240 → 目标存活。
  ap = 爪法；dp = 目标闪避；命中判 ap/2 + random(ap*2/3)。
  起手扣 50 内力；命中再扣 180 内力、忙乱 2，并按双方 max_neili/force 分三支：
    A) 修为被压制（max_neili < 目标 4/5 且 force < 目标 force）：仅震慑文案，无伤害；
    B) 修为碾压（max_neili > 目标 2 倍）：damage = -1 → target->die，即死；
    C) 常规：目标忙乱 1+random(3)，damage = (ap+force)/2 + random((ap+force)/2)，
       70% 外伤，命中部位取目标 limbs 随机（无则“要害”）。
  未命中忙乱 2。命中后令目标 kill_ob（框架内战斗关系已建立，不另建模）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jiuyin-baiguzhao/zhua"
  @move_name "「九阴神爪」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-baiguzhao")
    # LPC: ap = me->query_skill("claw");
    ap = Stats.skill(stats, "claw")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
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
          # 分支 A/B 需比较双方修为，攻击方快照随事件传给目标侧
          max_neili: character.meta.vitals.max_neili,
          force: Stats.skill(stats, "force"),
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  #          return notify_fail("你必须空手才能使用九阴神抓！\n");
  # 注：此句用的是字面“九阴神抓”（抓），非 ZHUA 宏的“九阴神爪”（爪）
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你必须空手才能使用九阴神抓！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jiuyin-baiguzhao", 1) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyin-baiguzhao") < 120 do
      {:error, "你的九阴白骨爪还不够娴熟，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "jiuyin-baiguzhao")
  # prepared_perform 返回绝招 ID（如 jiuyin-baiguzhao/zhua），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared = Stats.prepared_perform(stats, "claw")

    if prepared == nil or hd(String.split(prepared, "/")) != "jiuyin-baiguzhao" do
      {:error, "你没有准备九阴白骨爪，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 240 do
      {:error, "你现在内力太弱，不能使用九阴神抓。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = "$N冷笑一声…抓了下来。\n"; me->add("neili", -50); me->want_kill(target);
  defp apply_effect(conn, character, target) do
    msg = "$N冷笑一声，眼露凶光，右手成爪，三盘两旋虚虚实实的向$n的头顶抓了下来。\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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
    attacker_max_neili = Map.get(data, :max_neili, 0)
    attacker_force = Map.get(data, :force, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge");
    dp = Stats.skill(stats, "dodge")

    # LPC: if (ap / 2 + random(ap * 2 / 3) > dp)
    if div(ap, 2) + Engine.rand(rng, div(ap * 2, 3)) > dp do
      # LPC: me->start_busy(2); me->add("neili", -180);
      Performs.feedback(attacker, 180, 2)

      target_max_neili = character.meta.vitals.max_neili
      target_force = Stats.skill(stats, "force")

      cond do
        # LPC: if (me->query("max_neili") < target->query("max_neili") * 4 / 5 &&
        #          me->query_skill("force") < target->query_skill("force"))
        attacker_max_neili < div(target_max_neili * 4, 5) and attacker_force < target_force ->
          conn
          |> Broadcast.publish(
            Messages.interpolate(
              "“啪”的一声$N正抓在$n的天灵盖上，结果震得“哇哇”怪叫了两声！\n",
              bindings
            )
          )
          |> put_character(character)

        # LPC: else if (me->query("max_neili") > target->query("max_neili") * 2)
        #      { damage = -1; ... } ... if (damage < 0) target->die(me);
        attacker_max_neili > target_max_neili * 2 ->
          # target->die(me) —— 模型化为气血清零 + 死亡标记
          vitals = %{character.meta.vitals | qi: 0}
          combat = %{character.meta.combat | dead: true}
          character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

          conn
          |> Broadcast.publish(
            Messages.interpolate(
              "“扑哧”一声，$N五指正插入$n的天灵盖，$n一声惨叫，软绵绵的瘫了下去。\n",
              bindings
            )
          )
          |> put_character(character)

        true ->
          # LPC: target->start_busy(1 + random(3));
          combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 3))
          character = %{character | meta: %{character.meta | combat: combat}}

          # LPC: damage = ap + me->query_skill("force");
          #           damage = damage / 2 + random(damage / 2);
          damage_base = ap + attacker_force
          damage = div(damage_base, 2) + Engine.rand(rng, div(damage_base, 2))

          # LPC: if (arrayp(limbs = target->query("limbs")))
          #          limb = limbs[random(sizeof(limbs))];
          #      else limb = "要害";
          # 框架未建模角色个体 limbs，缺失时回退“要害”
          limb =
            case Map.get(character.meta, :limbs) do
              nil -> "要害"
              limbs -> Enum.at(limbs, max(Engine.rand(rng, length(limbs)) - 1, 0))
            end

          vitals =
            character.meta.vitals
            # LPC: do_damage(me, target, UNARMED_ATTACK, damage, 70, pmsg)
            |> Vitals.damage(:qi, damage)
            |> Vitals.wound(:qi, div(damage * 70, 100))

          character = %{character | meta: %{character.meta | vitals: vitals}}

          # LPC 的 pmsg 被 `+ limb +` 拆成两段字面量，E 侧须保持同样拆分
          msg =
            [
              "$n连忙腾挪躲闪，然而“扑哧”一声，$N五指正插入$n的",
              limb,
              "，$n一声惨叫，血射五步。\n"
            ]
            |> Enum.join("")

          conn
          |> Broadcast.publish(Messages.interpolate(msg, bindings))
          |> put_character(character)
      end
    else
      # LPC: 未命中：me->start_busy(2)
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$p看破了$P的企图，身形急动，躲开了这一抓。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhua.c 九阴白骨爪 - 九阴神抓
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # #define ZHUA "「" HIG "九阴神爪" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         string pmsg;
  #         string *limbs;
  #         string  limb;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyin-baiguzhao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUA "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用九阴神抓！\n");
  #                 
  #         if ((int)me->query_skill("jiuyin-baiguzhao", 1) < 120)
  #                 return notify_fail("你的九阴白骨爪还不够娴熟，不能使用" ZHUA "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "jiuyin-baiguzhao")
  #                 return notify_fail("你没有准备九阴白骨爪，无法使用" ZHUA "。\n");
  #                                 
  #         if ((int)me->query("neili", 1) < 240)
  #                 return notify_fail("你现在内力太弱，不能使用九阴神抓。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "冷笑一声，眼露凶光，右手成爪，三盘两旋虚虚"
  #               "实实的向$n" HIR "的头顶抓了下来。\n" NOR;
  # 
  #         me->add("neili", -50);
  # 
  #         me->want_kill(target);
  #         ap = me->query_skill("claw");
  #         dp = target->query_skill("dodge");
  #         if (ap / 2 + random(ap * 2 / 3) > dp)
  #         {
  #                 me->start_busy(2);
  #                 me->add("neili", -180);
  #                 damage = 0;
  # 
  #                 if (me->query("max_neili") < target->query("max_neili") * 4 / 5 &&
  #                     me->query_skill("force") < target->query_skill("force"))
  #                         msg += HIY "“啪”的一声$N" HIY "正抓在$n" HIY "的天灵盖上，"
  #                                "结果震得“哇哇”怪叫了两声！\n" NOR;
  #                 else
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIY "“扑哧”一声，$N" HIY "五指正插入$n" HIY "的天灵"
  #                                "盖，$n" HIY "一声惨叫，软绵绵的瘫了下去。\n" NOR;
  #                         damage = -1;
  #                 } else
  #                 {
  #                         target->start_busy(1 + random(3));
  #         
  #                         damage = ap + (int)me->query_skill("force");
  #                         damage = damage / 2 + random(damage / 2);
  #                         
  #                         if (arrayp(limbs = target->query("limbs")))
  #                                 limb = limbs[random(sizeof(limbs))];
  #                         else
  #                                 limb = "要害";
  #                         pmsg = HIC "$n连忙腾挪躲闪，然而“扑哧”一声，$N"
  #                                HIC "五指正插入$n" HIC "的" + limb + "，$n"
  #                                HIC "一声惨叫，血射五步。\n" NOR;
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70, pmsg);
  #                 }
  #         } else 
  #         {
  #                 me->start_busy(2);
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，身形急动，躲开了这一抓。\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  #         else
  #         if (! target->is_killing(me))
  #                 target->kill_ob(me);
  # 
  #         return 1;
  # }
end
