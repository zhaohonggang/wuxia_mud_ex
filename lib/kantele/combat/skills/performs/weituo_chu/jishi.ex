defmodule Kantele.Combat.Skills.Performs.WeituoChu.Jishi do
  @moduledoc """
  perform「jishi」（source weituo-chu/jishi.c，由 translate_perform.py 生成，inherit F_DBASE）

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

  @perform_id "weituo-chu/jishi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "weituo-chu")
    damage = (Stats.skill(stats, "weituo-chu") + Stats.skill(stats, "buddhism"))
    club = div(Stats.skill(stats, "staff"), 3)

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
  defp check_gates(character), do: check_levels(character)

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "weituo-chu") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"rigidity", "1"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"club", "staff"}, {"damage", "weituo-chu"}], "busy_lines": ["me->start_busy(1);"], "level_gates": [{"force", "120"}, {"weituo-chu", "120"}], "remote_damage": false, "temp_set": ["sl_leidong"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_DBASE;
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage, club;
  #         
  #         if (userp(me) && !me->query("can_perform/weituo-chu/jishi"))
  #                 return notify_fail("你还不会使用「即世即空」!\n");
  # 
  #         if( !target && me->is_fighting() ) target = offensive_target(me);
  # 
  #         if( !target
  #         ||  !target->is_character()
  #         ||  !me->is_fighting(target) )
  #                 return notify_fail("「即世即空」只能对战斗中的对手使用。\n");
  # 
  #         if( !objectp(weapon = me->query_temp("weapon")) 
  #            || weapon->query("skill_type") != "staff" )
  #                 return notify_fail("你手中无杵，怎能运用「即世即空」？！\n");
  # 
  #         if( me->query_temp("sl_leidong") )
  #                 return notify_fail("你刚使完「即世即空」，目前气血翻涌，无法再次运用！\n");
  #         
  #         if( (int)me->query_skill("weituo-chu", 1) < 120)
  #                 return notify_fail("你韦陀杵修为还不够，还未能使用「即世即空」！\n");
  # 
  #         if( me->query_skill("force", 1) < 120 )
  #                 return notify_fail("你的内功修为火候未到，施展只会伤及自身！\n");                             
  #       
  #         if( me->query("max_neili") <= 1500 )
  #                 return notify_fail("你的内力修为不足，劲力不足以施展「即世即空」！\n");
  # 
  #         if( me->query("neili") <= 600 )
  #                 return notify_fail("你的内力不够，劲力不足以施展「即世即空」！\n");
  # 
  #         message_vision(BLU "\n突然$N大喝一声：「即世即空」，面色唰的变得通红，须发皆飞，真气溶入" + 
  #                            weapon->name() + BLU "当中，“嗡”的一声，发出" HIW " 闪闪光亮 " BLU "！\n " NOR, me);
  #         
  #         damage = me->query_skill("weituo-chu", 1) + me->query_skill("buddhism",1);
  #         damage /= 6;
  #         club = me->query_skill("staff") / 3;
  #         
  #         if ( userp(me) ) 
  #         {
  #                 me->add("neili", -300);
  #                 me->start_busy(1);
  #                 if ( damage > weapon->query("weapon_prop/damage") * 2)
  #                      damage = weapon->query("weapon_prop/damage") * 2;
  #                 else weapon->add("rigidity", 1);
  #         }
  # 
  #         me->set_temp("sl_leidong", 1); 
  #         me->add_temp("apply/damage", damage);
  #         me->add_temp("apply/attack", damage);
  #         
  #         call_out("remove_effect1", club/2, me, weapon, damage);
  #         call_out("remove_effect2", club * 2/3, me);
  #         me->start_perform(club * 2 / 6, "「即世即空」");
  # 
  #         return 1;
  # }
  # 
  # void remove_effect1(object me, object weapon, int damage) 
  # {
  #         if (!me) return;
  #         me->add_temp("apply/attack", -damage);  
  # 
  #         if (!weapon) {
  #                 me->set_temp("apply/damage", 0);
  #                 return;
  #         }
  #         me->add_temp("apply/damage", -damage);
  #         message_vision(HIY "\n$N一套「即世即空」使完，手中"NOR + weapon->name() + HIY"上的光芒渐渐也消失了。\n"NOR, me);                
  # }
  # 
  # void remove_effect2(object me)
  # {
  #         if (!me) return;
  #         me->delete_temp("sl_leidong");
  #         tell_object(me, HIG "\n 你经过一段时间调气养息，又可以使用「即世即空」了。\n"NOR); 
  # }
end
