defmodule Kantele.Combat.Skills.Performs.QingyunBian.Duan do
  @moduledoc """
  perform「duan」（source qingyun-bian/duan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qingyun-bian/duan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qingyun-bian")
    power = 480

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
  defp check_gates(character), do: check_levels(character)

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "whip") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["armor", "attack", "damage", "dodge"], "assign_refs": [{"power", "qingyun-bian"}], "busy_lines": ["me->start_busy( 2 + random(2));"], "level_gates": [{"force", "100"}, {"whip", "100"}], "remote_damage": false, "var_gates": [{"power", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # //duan.c
  # // gladiator
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int str, power;
  #         // string weapon; 
  # 
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target
  #                 ||      !target->is_character()
  #                 ||      !me->is_fighting(target) )
  #                 return notify_fail("[断云决]只能对战斗中的对手使用。\n");
  # 
  #         if( me->query_skill("force",1) < 100 )
  #                 return notify_fail("你的基本内功火候未到，无法施展断云决！\n");
  # 
  #         if( me->query_skill("whip",1) < 100 )
  #                 return notify_fail("断云决需要精湛的青云鞭法方能有效施展！\n");
  # 
  #                 // for a 800K player, frce/2 = 150, shen/3K = 300, power = 300
  #                 // for players > 1.2M, power will hit max
  # 
  #         str = me->query_str();
  # 
  #         power = random( me->query_skill("qingyun-bian",1) / 3) + me->query_skill("force",1) / 2;
  # 
  #         if(power<150)power=150;
  #         if(power>480)power=480;
  # 
  #         if( me->query("neili") <= 200 )
  #                 return notify_fail("你的内力不够使用断云决！\n");
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         message_vision(HIW "$N运足内力，猛地一扬"NOR + "$n" +
  #                        HIW "卷起无边风云遮月掩日，一股"NOR +
  #                        HIM "罡风" NOR + HIW "随著漫天鞭影扑天盖地的向敌人袭来。\n"
  #                          NOR, me, me->query_temp("weapon"));
  # 
  #         me->add_temp("apply/attack", power / 5);
  #         me->add_temp("apply/damage", power / 5);
  #         target->add_temp("apply/armor",-power / 5);
  #         target->add_temp("apply/dodge",-power / 5);
  # 
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  # 
  #         if (random(10)>0) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>2) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>4) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>6) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>8) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  # 
  # 
  #         me->start_perform(1 + random(2),"[断云决]");
  # 
  #         me->add_temp("apply/attack", -power / 5);
  #         me->add_temp("apply/damage",-power / 5);
  #         target->add_temp("apply/armor",power / 5);
  #         target->add_temp("apply/dodge",power / 5);
  # 
  #         me->add("neili", -power);
  #         me->start_busy( 2 + random(2));
  # 
  #         return 1;
  # }
end
