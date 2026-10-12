defmodule Kantele.Combat.Skills.Performs.CanheZhi.Canhe do
  @moduledoc """
  perform「参合剑气」（source canhe-zhi/canhe.c，由 translate_perform.py 生成，inherit F_SSERVER）

  三段剑气：每段先判对手六脉神剑格反分支（剑气被折返，反伤攻击方），否则按该段
  各自的 ap/dp 公式调用 `COMBAT_D->do_damage`（直接伤害 + percent 比例外伤）或结算
  闪避文案。攻击方扣内力 / 忙乱 / 反伤经 `combat/perform-feedback` 事件回执。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "canhe-zhi/canhe"
  @move_name "「参合剑气」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: clv = me->query_skill("canhe-zhi", 1)
    #      原 .c 写作 `if (clv = (int)me->query_skill("canhe-zhi", 1) < 220)`，
    #      C 中 `=` 优先级低于 `<`，实际只把 0/1 存进 clv，使后面
    #      `slv >= clv - 60` 恒真；这里按 .c 注释说明的意图取真实等级。
    clv = Stats.skill(stats, "canhe-zhi")
    ap = Stats.skill(stats, "finger")
    base = Stats.skill(stats, "finger") + Stats.skill(stats, "force")
    # LPC: damage = finger + force; damage += random(damage);
    damage = base + Engine.rand(rng, max(base, 1))
    vitals = character.meta.vitals

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
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
          level: clv,
          skill: clv,
          ap: ap,
          damage: damage,
          rng: rng,
          clv: clv,
          # 攻击方气血快照：供目标侧推算 me->receive_wound 后的 p = qi*100/max_qi
          attacker_qi: vitals.qi,
          attacker_max_qi: vitals.max_qi
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "canhe-zhi") < 220 -> {:error, "你的参合指修为有限，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 320 -> {:error, "你的内功修为太差，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "canhe-zhi")
  defp check_prepared(character) do
    if prepared?(character.meta.stats, "canhe-zhi") do
      :ok
    else
      {:error, "你现在没有准备使用参合指，难以施展#{@move_name}。\n"}
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 6000 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 900 -> {:error, "你的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp prepared?(stats, id) do
    case Stats.prepared_perform(stats, "finger") do
      nil -> false
      value -> String.split(value, "/") |> hd() == id
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "只见$N" HIW "十指分摊，霎时破空声骤响，数股剑气至指尖激"
    #              "射而出，朝$n" HIW "径直奔去！\n" NOR;
    #      message_combatd(msg, me, target);
    #      me->start_busy(3 + random(3));
    #      me->add("neili", -400 - random(100));  /* 由目标侧结算后回执 */
    rng = &:rand.uniform/1
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 3))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "只见$N十指分摊，霎时破空声骤响，数股剑气至指尖激射而出，朝$n径直奔去！\n",
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
    clv = Map.get(data, :clv, 0)
    stats = character.meta.stats
    combat = character.meta.combat
    # LPC: slv = target->query_skill("liumai-shenjian", 1)
    slv = Stats.skill(stats, "liumai-shenjian")

    # LPC: 格反分支还要求 ! target->is_busy() 且 target 准备了六脉神剑
    reversed? = not Combat.busy?(combat) and prepared?(stats, "liumai-shenjian")

    # LPC: p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
    # 攻击方不在本进程，用 data 快照按 receive_wound 语义本地递减后取状态文案
    attacker_vitals = %Vitals{
      qi: Map.get(data, :attacker_qi, 0),
      max_qi: max(Map.get(data, :attacker_max_qi, 1), 1)
    }

    # 第一段：ap/dp = target->query_skill("dodge")，percent 64
    {conn, character, attacker_vitals, wound_one} =
      resolve_round(conn, character, attacker, %{
        rng: rng,
        ap: ap,
        damage: damage,
        slv: slv,
        clv: clv,
        reversed?: reversed?,
        attacker_vitals: attacker_vitals,
blood_msg: "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n",
miss_msg: "\n$n见$N来势汹涌，急忙飞身一跃而起，避开了这一击。\n",
        dp: Stats.skill(stats, "dodge"),
        min_slv: 140,
        roll: 5,
        margin: 60,
        ap_mul: 3,
        ap_div: 4,
        percent: 64,
        wound_base: 3,
        wound_rand: 4,
        reverse_msg:
          "\n但见$n斜斜一指点出，指出如风，剑气纵横，嗤然作响，竟将$N的剑气全部折回，反向自己射去！\n",
        hit_msg: "\n顿时只听“嗤啦”的一声，$n躲闪不及，剑气顿时穿胸而过，带出一蓬血雨。\n"
      })

    # 第二段：dp = target->query_skill("force")，percent 75
    {conn, character, attacker_vitals, wound_two} =
      resolve_round(conn, character, attacker, %{
        rng: rng,
        ap: ap,
        damage: damage,
        slv: slv,
        clv: clv,
        reversed?: reversed?,
        attacker_vitals: attacker_vitals,
blood_msg: "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n",
miss_msg: "\n$n见$N来势汹涌，急忙飞身一跃而起，避开了这一击。\n",
        dp: Stats.skill(stats, "force"),
        min_slv: 160,
        roll: 8,
        margin: 60,
        ap_mul: 3,
        ap_div: 4,
        percent: 75,
        wound_base: 2,
        wound_rand: 4,
        reverse_msg:
          "\n忽见$n左手小指一伸，一招「少泽剑」至指尖透出，真气鼓荡，轻灵迅速，顿将$N剑气逼回！\n",
        hit_msg: "\n只听$n一声惨嚎，被$N的剑气刺中了要害，血肉模糊，鲜血迸流不止。\n"
      })

    # 第三段：dp = target->query_skill("parry")，percent 100；
    # 格反成功时另有 me->start_busy(6)；此后不再需要攻击方气血快照
    {conn, character, _attacker_vitals, wound_three, busy} =
      resolve_round(conn, character, attacker, %{
        rng: rng,
        ap: ap,
        damage: damage,
        slv: slv,
        clv: clv,
        reversed?: reversed?,
        attacker_vitals: attacker_vitals,
blood_msg: "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n",
miss_msg: "\n$n见$N来势汹涌，急忙飞身一跃而起，避开了这一击。\n",
        dp: Stats.skill(stats, "parry"),
        min_slv: 180,
        roll: 10,
        margin: 50,
        ap_mul: 2,
        ap_div: 3,
        percent: 100,
        wound_base: 2,
        wound_rand: 2,
        last_round?: true,
        reverse_msg:
          "\n可电光火石之间，$n猛然翻掌，右手陡然探出，中指「中冲剑」向$N一竖，登将参合剑气化于无形！\n",
        hit_msg: "\n$n奋力招架，仍是不敌，$N的无形剑气已透体而入，鲜血飞射，无力再战。\n"
      })

    # LPC: me->add("neili", -400 - random(100));
    Performs.feedback(attacker, %{
      neili_cost: 400 + Engine.rand(rng, 100),
      busy: busy,
      wound_qi: wound_one + wound_two + wound_three
    })

    conn
    |> put_character(character)
  end

  # 单段结算（三段结构相同，仅门槛/公式/文案不同）：
  #   1) 格反分支：slv >= 140/160/180 && random(N) == 0 && slv >= clv - margin
  #      && ! target->is_busy() && target 准备了 liumai-shenjian
  #      -> me->receive_wound("qi", slv/N + random(slv/M), target)
  #         msg += "( $N" + eff_status_msg(p) + ")\n"
  #   2) 否则 ap*M/D + random(ap) > dp
  #      -> COMBAT_D->do_damage(..., damage, percent, msg)
  #         wound = (damage - random(armor)) * percent / 100（armor 未建模，按 percent 直算）
  #   3) 否则闪避文案
  # 返回 {conn, character, attacker_vitals, wound_qi, busy}
  defp resolve_round(conn, character, attacker, opts) do
    rng = opts.rng
    ap = opts.ap
    damage = opts.damage
    slv = opts.slv
    clv = opts.clv
    dp = opts.dp
    percent = opts.percent
    attacker_vitals = opts.attacker_vitals
    bindings = [n1: attacker.name, n2: character.name]

    reversed? =
      opts.reversed? and slv >= opts.min_slv and Engine.rand(rng, opts.roll) == 0 and
        slv >= clv - opts.margin

    if reversed? do
      # LPC: me->receive_wound("qi", slv/N + random(slv/M), target);
      wound = div(slv, opts.wound_base) + Engine.rand(rng, div(slv, opts.wound_rand))
      attacker_vitals = Vitals.wound(attacker_vitals, :qi, wound)
      ratio = div(attacker_vitals.qi * 100, max(attacker_vitals.max_qi, 1))

      conn =
        conn
        |> Broadcast.publish(opts.reverse_msg, bindings)
        |> Broadcast.publish(opts.blood_msg, bindings)
        |> Broadcast.publish("( $N#{Messages.eff_status_msg(ratio)})\n", n1: attacker.name)

      busy = if Map.get(opts, :last_round?, false), do: 6, else: 0
      {conn, character, attacker_vitals, wound, busy}
    else
      hit = div(ap * opts.ap_mul, opts.ap_div) + Engine.rand(rng, ap) > dp

      if hit do
        vitals = character.meta.vitals

        vitals =
          vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * percent, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}
        conn = Broadcast.publish(conn, opts.hit_msg, bindings)
        {conn, character, attacker_vitals, 0, 0}
      else
        conn =
          Broadcast.publish(conn, opts.miss_msg, bindings)

        {conn, character, attacker_vitals, 0, 0}
      end
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # #define CANHE "「" HIW "参合剑气" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp, slv, clv, p;
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "finger";
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/canhe-zhi/canhe"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CANHE "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" CANHE "。\n");
  # 
  #         if (clv = (int)me->query_skill("canhe-zhi", 1) < 220)
  #                 return notify_fail("你的参合指修为有限，难以施展" CANHE "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "canhe-zhi")
  #                 return notify_fail("你现在没有准备使用参合指，难以施展" CANHE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 320)
  #                 return notify_fail("你的内功修为太差，难以施展" CANHE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 6000)
  #                 return notify_fail("你的内力修为不足，难以施展" CANHE "。\n");
  # 
  #         if ((int)me->query("neili") < 900)
  #                 return notify_fail("你的真气不够，难以施展" CANHE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 5 / 100 / lvl;
  # 
  #         damage = me->query_skill("finger") + me->query_skill("force");
  #         damage += random(damage);
  #         slv = target->query_skill("liumai-shenjian", 1);
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("dodge");
  # 
  #         ap += ap * improve;
  # 
  #         msg = HIW "只见$N" HIW "十指分摊，霎时破空声骤响，数股剑气至指尖激"
  #               "射而出，朝$n" HIW "径直奔去！\n" NOR;
  # 
  #         me->start_busy(3 + random(3));
  # 
  #         if (slv >= 140
  #             && random(5) == 0
  #             && slv >= clv - 60 // 如果参合指等级比六脉神剑等级高60级以上取消特殊效果
  #             &&! target->is_busy()
  #             && target->query_skill_prepared("finger") == "liumai-shenjian")
  #         {
  #                 msg += HIY "\n但见$n" HIY "斜斜一指点出，指出如风，剑气纵横，嗤然"
  #                        "作响，竟将$N" HIY "的剑气全部折回，反向自己射去！\n" NOR +
  #                        HIR "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR;
  # 
  #                 me->receive_wound("qi", slv / 3 + random(slv / 4), target);
  #                 p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                 msg += "( $N" + eff_status_msg(p) + ")\n";
  # 
  #         } else
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 64,
  #                                            HIR "\n顿时只听“嗤啦”的一声，$n" HIR
  #                                            "躲闪不及，剑气顿时穿胸而过，带出一蓬"
  #                                            "血雨。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
  #                        "起，避开了这一击。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  # 
  #         if (slv >= 160
  #             && random(8) == 0
  #             && slv >= clv - 60  // 如果参合指等级比六脉神剑等级高60级以上取消特殊效果
  #             &&! target->is_busy()
  #             && target->query_skill_prepared("finger") == "liumai-shenjian")
  #         {
  #                 msg += HIY "\n忽见$n" HIY "左手小指一伸，一招「少泽剑」至指尖透出"
  #                        "，真气鼓荡，轻灵迅速，顿将$N" HIY "剑气逼回！\n" NOR + HIR
  #                        "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR;
  # 
  #                 me->receive_wound("qi", slv / 2 + random(slv / 4), target);
  #                 p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                 msg += "( $N" + eff_status_msg(p) + ")\n";
  # 
  #         } else
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
  #                                            HIR "\n只听$n" HIR "一声惨嚎，被$N" HIR
  #                                            "的剑气刺中了要害，血肉模糊，鲜血迸流不"
  #                                            "止。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
  #                        "起，避开了这一击。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  # 
  #         if (slv >= 180
  #             && random(10) == 0
  #             && slv >= clv - 50  // 如果参合指等级比六脉神剑等级高50级以上取消特殊效果
  #             &&! target->is_busy()
  #             && target->query_skill_prepared("finger") == "liumai-shenjian")
  #         {
  #                 msg += HIY "\n可电光火石之间，$n" HIY "猛然翻掌，右手陡然探出，中"
  #                        "指「中冲剑」向$N" HIY "一竖，登将参合剑气化于无形！\n" NOR
  #                        + HIR "你听到「嗤啦」一声轻响，脸上竟溅到一些血滴！\n" NOR;
  # 
  #                 me->receive_wound("qi", slv / 2 + random(slv / 2), target);
  #                 p = (int)me->query("qi") * 100 / (int)me->query("max_qi");
  #                 msg += "( $N" + eff_status_msg(p) + ")\n";
  #                 me->start_busy(6);
  # 
  #         } else
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
  #                                            HIR "\n$n" HIR "奋力招架，仍是不敌，$N"
  #                                            "的" HIR "无形剑气已透体而入，鲜血飞射"
  #                                            "，无力再战。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "\n$n" CYN "见$N" CYN "来势汹涌，急忙飞身一跃而"
  #                        "起，避开了这一击。\n" NOR;
  #         }
  #         me->add("neili", -400 - random(100));
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
