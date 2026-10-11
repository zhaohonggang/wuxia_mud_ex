defmodule Kantele.Combat.Skills.Performs.YintuoluoZhua.Chixue do
  @moduledoc """
  perform「赤血连环爪」（source yintuoluo-zhua/chixue.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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

  @perform_id "yintuoluo-zhua/chixue"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yintuoluo-zhua")
    i = 0

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yintuoluo-zhua") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "claw") != "yintuoluo-zhua" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "hunyuan-yiqi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "luohan-fumogong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "yijinjing" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 400}
    vitals = %{vitals | neili: vitals.neili - 500}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 500, 4)
    result = Messages.interpolate("$N运转少林真气，双手忽成爪行，施出绝招「赤血连环爪」，迅猛无比地抓向$n。
$n全身一颤，立足不稳，被$N这一爪抓得跌落在地上。
但见$N双爪划过，$n已闪避不及，胸口被$N抓出十条血痕。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-400"}, {"neili", "-500"}], "apply_adds": ["attack", "unarmed_damage"], "assign_refs": [{"ap", "claw"}, {"dp", "parry"}, {"lvl", "yintuoluo-zhua"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);", "//target->start_busy(lvl/30);", "me->start_busy(4);", "if (random(8) < 2 && !target->is_busy())", "target->start_busy(1);"], "level_gates": [{"force", "300"}, {"yintuoluo-zhua", "200"}], "map_gates": [{"claw", "yintuoluo-zhua"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [{"claw", "yintuoluo-zhua"}], "remote_damage": true, "resource_gates": [{"neili", "500"}], "set_flags": [{"eff_jing", "0"}, {"eff_qi", "0"}], "var_gates": [{"i", "4"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JU "「" HIR "赤血连环爪" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     int damage, lvl, i;
  #     string msg;
  #     int ap, dp;
  # 
  #     if (userp(me) && !me->query("can_perform/yintuoluo-zhua/chixue"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(JU "只能对战斗中的对手使用。\n");
  # 
  #     if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
  #         return notify_fail("你现在没有激发少林内功为内功，难以施展" JU "。\n");
  # 
  #     if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #         return notify_fail(JU "只能空手施展。\n");
  # 
  #     if ((int)me->query_skill("yintuoluo-zhua", 1) < 200)
  #         return notify_fail("你因陀罗爪不够娴熟，难以施展" JU "。\n");
  # 
  #     if (me->query_skill_mapped("claw") != "yintuoluo-zhua")
  #         return notify_fail("你没有激发因陀罗爪，难以施展" JU "。\n");
  # 
  #     if (me->query_skill_prepared("claw") != "yintuoluo-zhua")
  #         return notify_fail("你没有准备因陀罗爪，难以施展" JU "。\n");
  # 
  #     if (me->query_skill("force") < 300)
  #         return notify_fail("你的内功修为不够，难以施展" JU "。\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你现在的真气不够，难以施展" JU "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     ap = me->query_skill("claw") + me->query_skill("force") + me->query_str() + me->query_dex();
  #     dp = target->query_skill("parry") + target->query_skill("force") + target->query_str() + target->query_dex();
  #     lvl = (int)me->query_skill("yintuoluo-zhua", 1);
  #     msg = HIW "\n$N" HIW "运转少林真气，双手忽成爪行，施出绝招「" HIR "赤"
  #               "血连环爪" HIW "」，迅猛无比地抓向$n" HIW "。\n" NOR;
  # 
  #     if (ap * 3 / 4 + random(ap) > dp)
  #     {
  # 
  #         if (me->query("max_neili") > target->query("max_neili") * 2 && me->query("neili") > 500)
  #         {
  #             msg += HIR "$n" HIR "全身一颤，立足不稳，被$N" HIR "这一爪抓得跌落在地上。\n" NOR;
  # 
  #             me->add("neili", -500);
  #             me->start_busy(3);
  # 
  #             //  message_combatd(msg, me, target);
  # 
  #             target->set("eff_qi", 0);
  #             target->set("eff_jing", 0);
  #             // target->unconcious(me);
  #         }
  #         else
  #         {
  #             damage = ap + random(ap);
  #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 120,
  #                                        HIR "但见$N" HIR "双爪划过，$n" HIR "已闪避不及，胸口被$N" HIR
  #                                            "抓出十条血痕。\n" NOR);
  # 
  #             me->start_busy(3);
  #             //target->start_busy(lvl/30);
  #             me->add("neili", -400);
  #         }
  #     }
  #     else
  #     {
  #         msg += CYN "$n" CYN "奋力招架，竟将$N" CYN "这招化解。\n" NOR;
  # 
  #         me->start_busy(4);
  #         me->add("neili", -100);
  #     }
  #     message_sort(msg, me, target);
  #     me->add_temp("apply/attack", lvl / 2);
  #     me->add_temp("apply/unarmed_damage", lvl / 2);
  #     for (i = 0; i < 4; i++)
  #     {
  #         if (!me->is_fighting(target))
  #             break;
  #         if (random(8) < 2 && !target->is_busy())
  #             target->start_busy(1);
  # 
  #         COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  #     me->add_temp("apply/attack", -lvl / 2);
  #     me->add_temp("apply/unarmed_damage", -lvl / 2);
  #     return 1;
  # }
end
