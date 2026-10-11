defmodule Kantele.Combat.Skills.Performs.LuohanJian.Wuxing do
  @moduledoc """
  perform「wuxing」（source luohan-jian/wuxing.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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

  @perform_id "luohan-jian/wuxing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "luohan-jian")
    skill = Stats.skill(stats, "luohan-jian")
    extra = div(Stats.skill(stats, "luohan-jian"), 10)

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
      Stats.skill(stats, "luohan-jian") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
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
    Performs.feedback(attacker, 200, 3)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"extra", "luohan-jian"}, {"skill", "luohan-jian"}], "busy_lines": ["me->start_busy(3);"], "level_gates": [{"luohan-jian", "100"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # //来去若无形 wuxing.c 
  #          
  # #include <ansi.h> 
  # #include <skill.h> 
  # #include <weapon.h> 
  # #include <combat.h> 
  #          
  # //inherit F_CLEAN_UP; 
  #  
  # void remove_effect(object me, int a_amount, int d_amount); 
  #  
  # inherit F_SSERVER; 
  # int perform(object me, object target) 
  # { 
  #         object weapon; 
  #         int skill; 
  #         int extra; 
  #         string msg; 
  #   
  #         if ( !target ) target = offensive_target(me); 
  #          
  #         if ( !target 
  #                 ||      !target->is_character() 
  #                 ||      !me->is_fighting(target) ) 
  #                         return notify_fail("「来去若无形」只能在战斗中使用。\n"); 
  #  
  #         if (!objectp(weapon = me->query_temp("weapon")) 
  #                 || (string)weapon->query("skill_type") != "sword") 
  #                 return notify_fail("「来去若无形」必须用剑才能施展。\n"); 
  #          
  #         if( (int)me->query_skill("luohan-jian", 1) < 100 ) 
  #                 return notify_fail("你的「罗汉剑法」不够娴熟，不会使用「来去若无形」。\n"); 
  #  
  #         if( (int)me->query("neili") < 300  )  
  #                 return notify_fail("你的内力不够。\n"); 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #  
  #         skill = me->query_skill("luohan-jian",1); 
  #          
  #         extra = me->query_skill("luohan-jian",1) / 10; 
  #         extra += me->query_skill("luohan-jian",1) / 10; 
  #         me->add_temp("apply/attack", extra);     
  #         me->add_temp("apply/damage", extra); 
  #          
  #         msg = HIG "$N身行突变，瞬间犹如分出无数身影闪电般的向$n攻去！\n" NOR; 
  #                message_vision(msg, me, target);  
  #          
  #         me->add("neili", -200); 
  #          
  #         message_combatd(HIR "  来字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #          
  #         message_combatd(HIY "    去字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #  
  #         message_combatd(HIG "      若字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #          
  #         message_combatd(HIB "        无字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  #          
  #         message_combatd(HIW "          形字决！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
  #                                        TYPE_REGULAR);  
  # 
  #         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, skill, 80,  
  # 
  # 
  #                     HIC "            来去若无形    幻化无真境 \n" NOR); 
  #         message_combatd(msg, me, target);  
  # 
  # 
  #         me->start_busy(3); 
  #         me->add_temp("apply/attack", -extra); 
  #         me->add_temp("apply/damage", -extra); 
  #  
  #         return 1; 
  # } 
end
