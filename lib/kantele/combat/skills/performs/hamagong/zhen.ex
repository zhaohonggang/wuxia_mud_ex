defmodule Kantele.Combat.Skills.Performs.Hamagong.Zhen do
  @moduledoc """
  perform「蟾震九天」（source hamagong/zhen.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "hamagong/zhen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hamagong")
    skill = Stats.skill(stats, "hamagong")
    ap = Stats.skill(stats, "force")
    damage = ap
    hamagong_effect = div(skill, 30)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "strike") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "hamagong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("$n不料$N会使出如此诡异招式，慌忙伸掌抵挡，结果$N蛤蟆功内劲不断袭入，$n全身顿时感到一阵撕裂般的痛苦。
$n只觉此招，阴柔无比，诡异莫测，心中一惊，却猛然间觉得一股阴风透骨而过。
$n全然无力阻挡，竟被$N双掌击得飞起，重重的跌落在地上。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}, {"poison", "poison"}, {"skill", "hamagong"}], "busy_lines": ["me->start_busy(3 + random(4));"], "level_gates": [{"strike", "200"}], "map_gates": [{"strike", "hamagong"}], "prepared_gates": [{"strike", "hamagong"}], "remote_damage": true, "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}], "var_gates": [{"skill", "240"}]}

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
