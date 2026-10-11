defmodule Kantele.Combat.Skills.Performs.LiuheBian.Lianhuan do
  @moduledoc """
  perform「lianhuan」（source liuhe-bian/lianhuan.c，由 translate_perform.py 生成，inherit F_DBASE）

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

  @perform_id "liuhe-bian/lianhuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liuhe-bian")
    i = 1
    tm = (5 + Engine.rand(rng, 5))

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
         :ok <- check_mapped(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "dodge") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 270 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "liuhe-bian") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "whip") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "liuhe-bian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 300, 2)
    result = Messages.interpolate("$N大喝一声，口中轻轻念诵佛经，手中霍霍，招招连环，快如电闪！


【人合】，$N与合为一体急射向$n，$n措手不急被打的吐血不止！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "apply_adds": ["damage"], "assign_refs": [{"dp", "parry"}, {"lvl", "liuhe-bian"}, {"skill", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(2 + random(3));"], "level_gates": [{"dodge", "180"}, {"force", "270"}, {"liuhe-bian", "180"}, {"whip", "180"}], "map_gates": [{"whip", "liuhe-bian"}], "remote_damage": true, "temp_set": ["lianhuan"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  #          
  # #include <ansi.h> 
  # #include <combat.h> 
  #  
  # //inherit F_DBASE; 
  # inherit F_SSERVER; 
  #  
  # int perform(object me, object target) 
  # { 
  #         object weapon; 
  #         int skill, lvl, ap, dp, i; 
  #         string msg; 
  #         int damage, hurt, tm; 
  #          
  #         //if ( !userp(me) && !me->query("can_perform/liuhe-bian/lianhuan")) 
  #         //        return notify_fail("你所用的外功中没有这个功能!\n"); 
  #                  
  #         if ( !target ) target = offensive_target(me); 
  #          
  #         if ( !target 
  #                 ||   !target->is_character() 
  #                 ||   !me->is_fighting(target) ) 
  #                 return notify_fail("六合连环诀只能对战斗中的对手使用。\n"); 
  #          
  #         if ( me->query_temp("lianhuan") ) 
  #                 return notify_fail("你刚刚使用过六合连环诀，内力还未平复！\n");        
  #  
  #         weapon = me->query_temp("weapon"); 
  #  
  #         if (! objectp(weapon = me->query_temp("weapon"))  
  #                 || (string)weapon->query("skill_type") != "whip"  
  #                 || me->query_skill_mapped("whip") != "liuhe-bian" )  
  #                 return notify_fail("你手中无鞭，如何能够施展连环诀？\n");        
  #          
  #         if ( me->query_skill("force") < 270 ) 
  #                 return notify_fail("你的内功火候未到，无法配合鞭法施展连环诀！\n"); 
  #  
  #         if ( me->query_skill("whip", 1) < 180 ) 
  #                 return notify_fail("你鞭法修为不足，还不能使用连环诀！\n"); 
  #          
  #         if ( me->query_skill("liuhe-bian", 1) < 180 ) 
  #                 return notify_fail("你六合鞭法修为不足，还不能使用连环诀！\n");        
  #  
  #         if ( me->query("neili") <= 300 ) 
  #               return notify_fail("你的内力不够，无法施展！\n");        
  #                  
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n"); 
  #         if ( me->query_skill("dodge", 1) < 180 ) 
  #                 return notify_fail("你轻功修为不足，无法快速攻击！\n"); 
  #  
  #         skill = me->query_skill("force", 1) + me->query_skill("liuhe-bian", 1) + 
  #                 me->query_skill("dodge", 1); 
  #         lvl = me->query_skill("liuhe-bian", 1); 
  #         lvl = lvl / 3; 
  #          
  #         ap = skill + random(skill); 
  #  
  #         dp = target->query_skill("parry", 1) + target->query_skill("dodge", 1);     
  #          
  #         msg = HIR "\n$N大喝一声，口中轻轻念诵佛经，手中" +  
  #                        weapon->name() + "霍霍，招招连环，" 
  #                        "快如电闪！\n\n" NOR; 
  #         if (random(ap) > dp) 
  #         {     
  #              i = 6; 
  #              me->set_temp("lianhuan", 1); 
  #              me->add_temp("apply/damage", lvl); 
  #                  
  #              tm = 5 + random(5); 
  #          
  #              me->start_call_out( (: call_other, __FILE__, "remove_effect", me :), tm); 
  #              me->add("neili", -300); 
  #              me->start_busy(2);        
  #              hurt = skill / 3; 
  #               
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIY "\n【天合】，$N舞动手中" + weapon->name() +  
  #                     HIY "瞬息击向$n的额头，啪的一声轻响，顿时一条血印。\n" NOR); 
  #               
  #              i = 5; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIW "\n【地合】，$N一个横扫打向$n的下盘，$n未能看破企图，一声惨嚎，"  
  #                     + weapon->name() + HIW "鞭端已没入小腿半寸"  
  #                             "，登时连退数步！\n" NOR); 
  #               
  #              i = 4; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIR "\n【人合】，$N与" + weapon->name() + HIR"合为一体急射向$n，"  
  #                     "$n措手不急被打的吐血不止！\n" NOR); 
  #              i = 3; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIG "\n【神合】，$N手中" + weapon->name() + HIG "似有灵性一般" 
  #                     "死追着$n而去。\n" NOR); 
  #              i = 2; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIC "\n【鬼合】，$N突然面如死灰，动作僵硬，然后杀气却更胜一筹，"  
  #                     + weapon->name() + HIC "发出灵异的光芒，$n几乎看到了死亡的颜色。\n"    NOR); 
  #          
  #                 i = 1; 
  #              damage = hurt / i; 
  #              msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,  
  #                     HIB "\n【六合】，$N口中高唱佛号，手中" + weapon->name() +  
  #                     HIB "连环击出，鞭影重重，$n再也支持不住，身上被拉出一条条豁口。\n" NOR); 
  #               
  #          } else 
  #          { 
  #              msg += CYN "$n" CYN "不慌不忙，以快打快，将$N" 
  #                     CYN "的招式完全化去。\n" NOR; 
  #              me->add("neili", -200); 
  #              me->start_busy(2 + random(3));  
  #          } 
  #         message_combatd(msg, me, target);  
  #         return 1; 
  # } 
  #  
  # void remove_effect(object me, int amount) 
  # { 
  #         int lvl; 
  #         lvl = (int)me->query_skill("liuhe-bian", 1); 
  #         lvl = lvl / 3; 
  #         me->delete_temp("lianhuan"); 
  #  
  #         if ( me->is_fighting() ) { 
  #                 message_vision(HIR "\n$N将内力收回丹田，手上招数也逐渐慢了下来。\n\n" NOR, me);    
  #         } 
  #         else { 
  #                 tell_object(me, HIR "\n你的内功运行完毕，将内力缓缓收回丹田。\n\n" NOR); 
  #         } 
  #         me->add_temp("apply/damage", -lvl); 
  #  
  # } 
end
