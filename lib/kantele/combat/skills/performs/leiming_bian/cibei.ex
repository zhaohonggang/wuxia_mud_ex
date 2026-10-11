defmodule Kantele.Combat.Skills.Performs.LeimingBian.Cibei do
  @moduledoc """
  perform「cibei」（source leiming-bian/cibei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "leiming-bian/cibei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "leiming-bian")
    extra = Stats.skill(stats, "leiming-bian")
    skill = Stats.skill(stats, "buddhism")
    damage = 1500
    lmt = 6
    i = 1

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 300}
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
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :qi, damage)
        vitals = Vitals.wound(vitals, :qi, div(damage, 3))
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"at", "leiming-bian"}, {"df", "dodge"}, {"extra", "leiming-bian"}, {"lmt", "leiming-bian"}, {"skill", "buddhism"}], "busy_lines": ["target->start_busy(3);", "me->start_busy(random(2) + 2);", "me->start_busy(random(2));"], "remote_damage": false, "resource_gates": [{"neili", "1500"}, {"shen", "200000"}], "var_gates": [{"extra", "160"}, {"lmt", "3"}, {"skill", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # int perform(object me, object target)
  # {
  #         string msg; 
  #         int extra, skill, at, df, i, lmt, damage, p;
  #         object weapon;
  #         extra = me->query_skill("leiming-bian",1);
  # 
  #         //if (userp(me) && !me->query("can_perform/leiming-bian/cibei"))
  #        //       return notify_fail("你使用的外功中没有这个功能。\n");
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target
  #                  || !target->is_character()
  #                  || !me->is_fighting(target) )
  #               return notify_fail("［慈悲字诀］只能对战斗中的对手使用。\n");
  # 
  #         if( extra < 160)
  #               return notify_fail("你的雷鸣鞭法修为太差,还不能使用慈悲字诀！\n");
  # 
  #         skill = me->query_skill("buddhism", 1);
  # 
  #         if( skill < 150)
  #               return notify_fail("你的禅宗心法等级不够，怎能支持慈悲字诀？ \n");
  # 
  #         if( me->query("shen") < 200000)
  #               return notify_fail("慈悲字诀需以无边正气为辅,大师还是多行善事吧! \n");
  # 
  #         if( me->query("neili") < 1500 )
  #               return notify_fail("你的内力修为不够辅助慈悲字诀。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if( !weapon
  #          || weapon->query("skill_type") != "whip")
  #               return notify_fail("你手中没有兵器如何使用慈悲字诀。\n");
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = RED "只见$N喃喃自语道：慈悲为怀，手中的" + weapon->name() + RED "仿佛如来出世般倒卷向$n。\n" NOR;
  # 
  #         at = me->query("combat_exp") * me->query_skill("leiming-bian", 1) / 1000;
  #         df = target->query("combat_exp") * target->query_skill("dodge", 1) / 1000;
  # 
  #         if( (random(at) + at / 2)  > df )
  #         {
  #             damage = me->query("shen", 1) / 2000;
  # 
  #             //if(damage > 1500) damage = 1500 + (damage-1500)/100;
  #             if(damage > 1500) damage = 1500; //设定上限 2017-02-03
  # 
  #             msg += CYN "$n不禁被$N的无边佛法打动，猛的后退，脸上没有一丝血色...\n" NOR;
  #             target->receive_damage("qi", damage, me);
  #             target->receive_wound("qi", damage / 3, me);
  # 
  #             p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  #             msg += "( $n" + eff_status_msg(p) + " )\n";
  #             message_vision(msg, me, target);
  #             target->start_busy(3);
  # 
  #             weapon = me->query_temp("weapon");
  #             msg = HIG "\n紧接着$N手中的" + weapon->name() + HIG "连续晃动，竟然不知道有多少击。\n" NOR;
  #             message_vision(msg,me,target);
  # 
  #             lmt = random(me->query_skill("leiming-bian", 1) / 50) + 1;
  #             if ( lmt < 3 ) lmt = 3;
  #             if ( lmt > 6 ) lmt = 6;
  # 
  #             for(i=1;i <= lmt;i++)
  #             {
  #                  extra = me->query_skill("leiming-bian", 1);
  #                  me->add_temp("apply/attack", extra / 5);
  #                  me->add_temp("apply/damage", extra / 5);
  #                  COMBAT_D->do_attack(me,target, me->query_temp("weapon"), 1);
  #                  me->add_temp("apply/attack",-extra / 5);
  #                  me->add_temp("apply/damage",-extra / 5);
  #             }
  #             me->add("neili",-300);
  #             me->start_busy(random(2) + 2);
  #         } else
  #        {
  #               msg = HIG "\n$n左躲右闪，强$N的攻击完全化于无形！\n" NOR;
  #               message_vision(msg,me,target);
  #               me->add("neili",-200);
  #               me->start_busy(random(2));
  #        }
  #         return 1;
  # }
end
