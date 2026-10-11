defmodule Kantele.Combat.Skills.Performs.SixFinger.Six do
  @moduledoc """
  perform「六脉剑气」（source six-finger/six.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "six-finger/six"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "six-finger")
    skill = Stats.skill(stats, "liumai-shenjian")
    ap = Stats.skill(stats, "finger")
    delta = 0
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
          ap: ap,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 400 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 7000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    Performs.feedback(attacker, 400, 1)
    result = Messages.interpolate("$n见此剑气纵横，微一愣神，不禁心萌退意。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}], "apply_adds": ["dodge", "parry"], "assign_refs": [{"ap", "finger"}, {"dp", "force"}, {"skill", "liumai-shenjian"}], "busy_lines": ["if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"force", "400"}], "prepared_gates": [{"finger", "liumai-shenjian"}], "remote_damage": false, "resource_gates": [{"max_neili", "7000"}, {"neili", "500"}], "var_gates": [{"i", "6"}, {"skill", "220"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define SIX "「" HIW "六脉剑气" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # 
  # int perform(object me, object target)
  # {
  # //      mapping prepare;
  #         string msg;
  #         int skill;
  #         int delta;
  #         int i;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/six"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SIX "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
  #                 return notify_fail("你没有准备使用六脉神剑，无法施展" SIX "。\n");
  # 
  #         skill = me->query_skill("liumai-shenjian", 1);
  # 
  #         if (skill < 220)
  #                 return notify_fail("你的六脉神剑修为有限，无法使用" SIX "！\n");
  # 
  #         if (me->query_skill("force") < 400)
  #                 return notify_fail("你的内功火候不够，难以施展" SIX "！\n");
  # 
  #         if (me->query("max_neili") < 7000)
  #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内"
  #                                    "力形成" SIX "！\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，现在无法施展" SIX "！\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展" SIX "！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "摊开双手，手指连弹，霎时间空气炙热，几"
  #               "欲沸腾，六道剑气分自六穴，一起冲向$n" HIW "！\n" NOR;
  # 
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIR "$n" HIR "见此剑气纵横，微一愣神，不禁心萌退意。\n" NOR;
  #                 delta = -random(skill / 5);
  #         } else
  #                 delta = 0;
  # 
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -400);
  #         target->add_temp("apply/parry", delta);
  #         target->add_temp("apply/dodge", delta);
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(2) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 me->set_temp("liumai-shenjian/hit_msg", i);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, i * 3);
  #         }
  #         target->add_temp("apply/parry", -delta);
  #         target->add_temp("apply/dodge", -delta);
  #         me->delete_temp("liumai-shenjian/hit_msg");
  #         me->start_busy(1 + random(5));
  # 
  #         return 1;
  # }
end
