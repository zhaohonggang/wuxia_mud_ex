defmodule Kantele.Combat.Skills.Performs.ShouYin.Jie do
  @moduledoc """
  perform「jie」（source shou-yin/jie.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shou-yin/jie"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shou-yin")
    count = 0
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shou-yin") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.qi < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    vitals = %{vitals | qi: vitals.qi - 100}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$n面对$P这排山倒海攻势，完全无法抵挡，唯有退后。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"qi", "-100"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"force", "300"}, {"shou-yin", "150"}], "prepared_gates": [{"hand", "shou-yin"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}, {"qi", "800"}], "var_gates": [{"i", "9"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // jie.c 天劫
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「天劫」只能在战斗中对对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail("「天劫」只能空手使用。\n");
  #                 
  #         if (me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为还不够，无法施展天劫。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #         if ((int)me->query("qi") < 800)
  #                 return notify_fail("你的体力现在不够！\n");
  # 
  #         if ((int)me->query_skill("shou-yin", 1) < 150)
  #                 return notify_fail("你的手印火候不够，无法使用天劫！\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功修为不够，无法使用天劫！\n");
  # 
  #         if (me->query_skill_prepared("hand") != "shou-yin")
  #                 return notify_fail("你现在没有准备使用手印，无法使用天劫！\n");
  # 
  #         msg = HIW "$N" HIW "一声暴喝，双手猛然翻滚，"
  #               "刹那间只见无数的手印铺天盖地蜂拥而出，"
  #               "气势恢弘，无与伦比。\n" NOR;
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 6;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 9;
  #                 msg += HIR "$n" HIR "面对$P" HIR "这排山倒海攻势，完全"
  #                        "无法抵挡，唯有退后。\n" NOR;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC
  #                        "这几掌。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_vision(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  #         me->add("qi", -100);    // Why I don't use receive_damage ?
  #                                 // Becuase now I was use it as a cost
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
