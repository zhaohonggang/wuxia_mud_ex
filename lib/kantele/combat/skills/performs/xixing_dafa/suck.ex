defmodule Kantele.Combat.Skills.Performs.XixingDafa.Suck do
  @moduledoc """
  exert「suck」（source xixing-dafa/suck.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with {:ok, target} <- check_target(character),
         :ok <- check_gates(character, target) do
      resolve(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! objectp(target) || ! me->is_fighting(target))
  #         return notify_fail("你只能吸取战斗中的对手的丹元！\n");
  defp check_target(character) do
    case character.meta.combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能吸取战斗中的对手的丹元！\n"}
    end
  end

  defp check_gates(character, target) do
    with :ok <- check_no_fight(character),
         :ok <- check_race(target),
         :ok <- check_cooldown(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_can_absorb_more(character),
         :ok <- check_target_has_neili(target),
         :ok <- check_target_not_weak(character, target),
         :ok <- check_not_taixuan(target) do
      :ok
    end
  end

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("在这里不能攻击他人。\n");
  # 房间 no_fight 标记未建模，恒为 :ok，但保留文案以对齐 .c。
  defp check_no_fight(_character) do
    _ = "在这里不能攻击他人。\n"
    :ok
  end

  # LPC: if (target->query("race") != "人类" || target->query("not_living"))
  #         return notify_fail("搞错了！只有活着的生物才能有丹元！\n");
  defp check_race(target) do
    if Map.get(target.meta, :race) == "人类" do
      :ok
    else
      {:error, "搞错了！只有活着的生物才能有丹元！\n"}
    end
  end

  # LPC: if (me->query_temp("sucked")) return notify_fail("你刚刚吸取过丹元！\n");
  defp check_cooldown(character) do
    if Combat.buff_active?(character.meta.combat, "sucked") do
      {:error, "你刚刚吸取过丹元！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("xixing-dafa",1) < 200)
  #         return notify_fail("你的吸星大法尚未大成，还不能吸取对方的丹元收为己用！\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "xixing-dafa") < 200 do
      {:error, "你的吸星大法尚未大成，还不能吸取对方的丹元收为己用！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够，不能使用吸星大法。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够，不能使用吸星大法。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_current_neili_limit() <= my_max)
  #         return notify_fail("你的内功水平有限，再吸取也是徒劳。\n");
  defp check_can_absorb_more(character) do
    my_max = character.meta.vitals.max_neili
    limit = Map.get(character.meta.stats, :max_neili_limit) || my_max * 2

    if my_max < limit do
      :ok
    else
      {:error, "你的内功水平有限，再吸取也是徒劳。\n"}
    end
  end

  # LPC: if ((int)target->query("max_neili") < 100)
  #         return notify_fail(target->name() + "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n");
  defp check_target_has_neili(target) do
    if target.meta.vitals.max_neili >= 100 do
      :ok
    else
      {:error, target.name <> "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
    end
  end

  # LPC: if ((int)target->query("max_neili") < (int)me->query("max_neili") / 5)
  #         return notify_fail(target->name() + "的内功修为远不如你，你无法从他体内吸取丹元！\n");
  defp check_target_not_weak(character, target) do
    if target.meta.vitals.max_neili < div(character.meta.vitals.max_neili, 5) do
      {:error, target.name <> "的内功修为远不如你，你无法从他体内吸取丹元！\n"}
    else
      :ok
    end
  end

  # LPC: if (target->query_skill_mapped("force") == "taixuan-gong")
  #       { tell_object(target, HIW + me->name() + HIW "伸出右手，轻轻握在你的手"
  #                    "臂上，试图吸取你的内力，但是你体内的太玄真气猛地将"
  #                    "其反弹回去。\n");
  #         return notify_fail(HIG "你伸出右手，轻轻握在" + target->name() + "的手臂上，却猛的感觉一股内劲将你的手弹回。\n" NOR); }
  defp check_not_taixuan(target) do
    if Map.get(target.meta.stats.mapped || %{}, "force") == "taixuan-gong" do
      _ = "伸出右手，轻轻握在你的手臂上，试图吸取你的内力，但是你体内的太玄真气猛地将其反弹回去。\n"

      {:error, "你伸出右手，轻轻握在" <> target.name <> "的手臂上，却猛的感觉一股内劲将你的手弹回。\n"}
    else
      :ok
    end
  end

  defp resolve(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 10}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    conn = broadcast_open(conn, character, target)

    sp = Stats.skill(character.meta.stats, "force")
    dp = Stats.skill(target.meta.stats, "force")

    if sp + :rand.uniform(sp) > dp + :rand.uniform(dp) or target.meta.combat.dead do
      resolve_hit(conn, character, target)
    else
      resolve_miss(conn, character, target)
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")))
  #         message_combatd(... "探出右手，平平的拍在$n的胸前，似乎没有半点力道。\n\n" ..., me, target);
  #       else message_combatd(... "把手中的" + weapon->name() + "一扬，慢慢的逼向$n，$p连忙架住。\n" ..., me, target);
  defp broadcast_open(conn, character, target) do
    case Combat.weapon(character.meta.combat) do
      nil ->
        Broadcast.publish(conn, "$N探出右手，平平的拍在$n的胸前，似乎没有半点力道。\n\n",
          n1: character.name,
          n2: target.name
        )

      weapon ->
        wn = Map.get(weapon, :name) || "weapon"

        conn
        |> Broadcast.publish("$N把手中的" <> wn <> "一扬，慢慢的逼向$n",
          n1: character.name,
          n2: target.name
        )
        |> Broadcast.publish("，$p连忙架住。\n", n1: character.name, n2: target.name)
    end
  end

  # LPC: tell_object(target, HIR "你只觉全身乏力，全身功力如融雪般消失得无影无踪！\n" NOR);
  #      tell_object(me, HIG "你觉得" + target->name() + "的丹元自手掌源源不绝地流了进来。\n" NOR);
  defp resolve_hit(conn, character, target) do
    conn =
      conn
      |> Broadcast.publish("你只觉全身乏力，全身功力如融雪般消失得无影无踪！\n", n2: target.name)
      |> Broadcast.publish("你觉得" <> target.name <> "的丹元自手掌源源不绝地流了进来。\n",
        n1: character.name
      )

    amount = 1 + div(Stats.skill(character.meta.stats, "xixing-dafa") - 120, 10)

    character = %{
      character
      | meta: %{
          character.meta
          | vitals: %{character.meta.vitals | max_neili: character.meta.vitals.max_neili + amount},
            combat: Combat.start_busy(character.meta.combat, 4)
        }
    }

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: message_combatd(HIY "可是$p" HIY "看破了$P" HIY "的企图，运用内力震开了$P" HIY "，随即躲了开去。\n" NOR, me, target);
  defp resolve_miss(conn, character, target) do
    conn =
      Broadcast.publish(conn, "可是$p看破了$P的企图，运用内力震开了$P，随即躲了开去。\n",
        n1: character.name,
        n2: target.name
      )

    character = %{
      character
      | meta: %{character.meta | combat: Combat.start_busy(character.meta.combat, 7)}
    }

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}], "assign_refs": [{"amount", "xixing-dafa"}, {"dp", "force"}, {"sp", "force"}], "busy_lines": ["me->start_busy(4 + random(4));", "if (! target->is_busy()) target->start_busy(2);", "me->start_busy(7);"], "level_gates": [{"xixing-dafa", "200"}], "remote_damage": false, "resource_gates": [{"max_neili", "1"}, {"max_neili", "100"}, {"neili", "100"}], "set_flags": [{"max_neili", "0"}], "temp_set": ["sucked"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // suck.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #     int sp, dp;
  #     int my_max, tg_max;
  #         int amount;
  #         object weapon;
  # 
  #     if (! target || target == me) target = offensive_target(me);
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("在这里不能攻击他人。\n");
  # 
  #     if (! objectp(target) || ! me->is_fighting(target))
  #         return notify_fail("你只能吸取战斗中的对手的丹元！\n");
  # 
  #         if (target->query("race") != "人类" ||
  #             target->query("not_living"))
  #                 return notify_fail("搞错了！只有活着的生物才能有丹元！\n");
  # 
  #         my_max = me->query("max_neili");
  #         tg_max = target->query("max_neili");
  # 
  #     if (me->query_temp("sucked"))
  #         return notify_fail("你刚刚吸取过丹元！\n");
  # 
  #         if (! me->is_fighting() || ! target->is_fighting())
  # 
  #     if ((int)me->query_skill("xixing-dafa", 1) < 200)
  #         return notify_fail("你的吸星大法尚未大成，还"
  #                                    "不能吸取对方的丹元收为己用！\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够，不能使用吸星大法。\n");
  # 
  #         if ((int)me->query_current_neili_limit() <= my_max)
  #                 return notify_fail("你的内功水平有限，再吸取也是徒劳。\n");
  # 
  #     if ((int)target->query("max_neili") < 100)
  #         return notify_fail( target->name() +
  #             "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n");
  # 
  #         if ((int)target->query("max_neili") < (int)me->query("max_neili") / 5)
  #         return notify_fail( target->name() +
  #             "的内功修为远不如你，你无法从他体内吸取丹元！\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")))
  #             message_combatd(HIR "$N" HIR "探出右手，平平的拍在$n"
  #                                 HIR "的胸前，似乎没有半点力道。\n\n" NOR,
  #                                 me, target);
  #         else
  #                 message_combatd(HIR "$N" HIR "把手中的" + weapon->name() +
  #                                 HIR "一扬，慢慢的逼向$n" HIR + "，$p"
  #                                 HIR "连忙架住。\n" NOR,
  #                                 me, target);
  # 
  #         if (target->query_skill_mapped("force") == "taixuan-gong")
  #         {
  #                 tell_object(target, HIW + me->name() + HIW "伸出右手，轻轻握在你的手"
  #                              "臂上，试图吸取你的内力，但是你体内的太玄真气猛地将"
  #                              "其反弹回去。\n");
  # 
  #                 return notify_fail(HIG "你伸出右手，轻轻握在" + target->name() +
  #                                    HIG "的手臂上，却猛的感觉一股内劲将你的手弹回。\n" NOR);
  #         }
  # 
  #         if (living(target) && !target->is_killing(me))
  #         {
  #                 me->want_kill(target);
  #                 target->kill_ob(me);
  #         }
  # 
  #         sp = me->query_skill("force");
  #         dp = target->query_skill("force");
  # 
  #     me->set_temp("sucked", 1);
  # 
  #         if ((sp + random(sp) > dp + random(dp) ) || ! living(target))
  #     {
  #         tell_object(target, HIR "你只觉全身乏力，全身功力如"
  #                 "融雪般消失得无影无踪！\n" NOR);
  #         tell_object(me, HIG "你觉得" + target->name() +
  #                 HIG "的丹元自手掌源源不绝地流了进来。\n" NOR);
  # 
  #                 amount = 1 + (me->query_skill("xixing-dafa", 1) - 120) / 10;
  #                 target->add("max_neili", -amount);
  #                 me->add("max_neili", amount);
  #                 me->add("exception/xixing-count", amount * 10);
  #                 SKILL_D("xixing-dafa")->check_count(me);
  #                 if (target->query("max_neili") < 1)
  #             target->set("max_neili", 0);
  # 
  #                 me->start_busy(4 + random(4));
  #                 if (! target->is_busy()) target->start_busy(2);
  #                 me->add("neili", -10);
  # 
  #         call_out("del_sucked", 10, me);
  #     } else
  #     {
  #         message_combatd(HIY "可是$p" HIY "看破了$P" HIY
  #                                 "的企图，运用内力震开了$P" HIY
  #                                 "，随即躲了开去。\n" NOR,
  #                                 me, target);
  #                 me->start_busy(7);
  #         call_out("del_sucked", 20, me);
  #     }
  # 
  #     return 1;
  # }
  # 
  # void del_sucked(object me)
  # {
  #         me->delete_temp("sucked");
  # }
end
