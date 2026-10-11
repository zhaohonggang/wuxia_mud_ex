defmodule Kantele.Combat.Skills.Performs.DacidabeiShou.Yin do
  @moduledoc """
  perform「yin」（source dacidabei-shou/yin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "dacidabei-shou/yin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "dacidabei-shou")

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
      Stats.skill(stats, "buddhism") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "dacidabei-shou") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "hand") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
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

  # TODO(migrate) 目标侧结算：命中/闪避/伤害公式与文案需按原始源码（见文末）补齐。
  #   target->receive_damage("qi", damage)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("qi", damage/3)  # UNSUPPORTED: unknown ident damage

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"damage", "dacidabei-shou"}], "busy_lines": ["me->start_busy(2+random(2));"], "level_gates": [{"buddhism", "200"}, {"dacidabei-shou", "180"}, {"hand", "180"}], "prepared_gates": [{"hand", "dacidabei-shou"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "800"}], "set_flags": [{"value", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # #include "/kungfu/skill/eff_msg.h";
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #       string msg, dodge_skill;                                
  #       int damage, jiali, attack, defense, p;
  #       object armor;
  # 
  # 
  #       if (me->query_skill("buddhism", 1) < 200)
  #            return notify_fail("你的佛法修为不足，无法施展该绝招！\n");
  #       
  #       if( !target ) target = offensive_target(me);
  #      
  #       if( !target || !me->is_fighting(target) || !living(target) )
  #            return notify_fail("「大手印」只能在战斗中对对手使用。\n");        
  #       
  #       if( (int)me->query_skill("dacidabei-shou",1) < 180 )
  #            return notify_fail("你的大慈大悲手不够娴熟，不会使用「大手印」！\n");
  #       
  #       if( (int)me->query_skill("hand",1) < 180 )
  #            return notify_fail("你的基本手法不够娴熟，不会使用「大手印」！\n");
  # 
  #       if( (int)me->query_str() < 35 )
  #            return notify_fail("你的臂力不够强，不能使用「大手印」！\n");
  #       
  #       if( (int)me->query("max_neili") < 2000 )
  #            return notify_fail("你的内力太弱，不能使用「大手印」！\n");
  #       
  #       if( (int)me->query("neili") < 800 )
  #            return notify_fail("你的内力太少了，无法使用出「大手印」！\n");   
  #        
  #       if (me->query_skill_prepared("hand") != "dacidabei-shou")
  #            return notify_fail("你还没有准备大慈大悲手，无法施展「大手印」！\n");   
  #           
  #       if( objectp(me->query_temp("weapon")) )
  #            return notify_fail("你必须空手使用「大手印」！\n");                                                                              
  #       jiali = me->query("jiali")+1;
  #       attack = me->query("combat_exp")/1000;
  #       attack += me->query_skill("hand");
  #       attack += me->query("neili")/5;
  #       defense = target->query("combat_exp")/1000;
  #       defense += target->query_skill("dodge");
  #       defense += target->query("neili")/7;
  #       attack = (attack+random(attack+1))/2;
  #       
  #       damage = me->query_skill("dacidabei-shou", 1)/40 * jiali;
  #       
  #       message_vision(HIR "\n$N突然面色通红，低声默念禅宗真言，双臂骨节一阵爆响，猛然"
  #                      "腾空而起，伸手向$n胸前按去，好一式「大手印」！\n"NOR,me,target);
  #  
  #       if( attack > defense ) { 
  #          if( objectp(armor = target->query_temp("armor/cloth"))
  #             && armor->query("armor_prop/armor") < 200
  #             && damage > 500){
  #                         message_vision(HIY"只见这斗大的手印正好印在$N的$n"HIY"上，越变越"
  #                                        "大，竟将它震得粉碎，裂成一块块掉在地上！\n"NOR, target, armor);
  #                         armor->unequip();
  #                         armor->move(environment(target));
  #                         armor->set("name", "破碎的" + armor->query("name"));    
  #                         armor->set("value", 0);
  #                         armor->set("armor_prop/armor", 0);
  #                         target->reset_action();
  #                         }
  #          tell_object(target, RED"你只觉得霍的胸口一阵剧痛，已经被拍中了前胸！\n"NOR);
  #          target->receive_damage("qi", damage,  me);
  #          target->receive_wound("qi", damage/3, me);
  #          p = (int)target->query("qi")*100/(int)target->query("max_qi");
  # 
  #          msg = "( $n"+eff_status_msg(p)+" )\n";
  #          message_vision(msg, me, target);
  #          me->add("neili", -jiali);
  #         }
  #       else {
  #          dodge_skill = target->query_skill_mapped("dodge");
  #          if( !dodge_skill ) dodge_skill = "dodge";
  #          message_vision(SKILL_D(dodge_skill)->query_dodge_msg(target, 1), me, target);
  #          }
  #       me->add("neili", -200);
  #       me->start_busy(2+random(2));            
  #       return 1;
  # }
end
