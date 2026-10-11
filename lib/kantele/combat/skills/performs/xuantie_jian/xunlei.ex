defmodule Kantele.Combat.Skills.Performs.XuantieJian.Xunlei do
  @moduledoc """
  perform「xunlei」（source xuantie-jian/xunlei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuantie-jian/xunlei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuantie-jian")
    j = Stats.skill(stats, "xuantie-jian")
    z = Stats.skill(stats, "surge-force")

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
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "surge-force") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuantie-jian") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "parry") != "xuantie-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "xuantie-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 900 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 350}
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
    Performs.feedback(attacker, 350, 3)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-350"}], "apply_adds": ["attack", "str"], "assign_refs": [{"j", "xuantie-jian"}, {"z", "surge-force"}], "busy_lines": ["me->start_busy(3);", "if( !target->is_busy() )", "target->start_busy(1);"], "level_gates": [{"force", "200"}, {"surge-force", "160"}, {"xuantie-jian", "160"}], "map_gates": [{"parry", "xuantie-jian"}, {"sword", "xuantie-jian"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "900"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int j, z;
  #         object weapon;
  #         
  #         /*
  #         if (userp(me) && ! me->query("can_perform/xuantie-jian/xunlei"))
  #                 return notify_fail("你未得高人指点，不知该如何施展「迅雷击」。\n");
  #         */
  #                         
  #         j = me->query_skill("xuantie-jian", 1);
  #         z = me->query_skill("surge-force", 1);
  #  
  #         weapon = me->query_temp("weapon");
  # 
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target || !me->is_fighting(target) )
  #                 return notify_fail("「迅雷击」只能在战斗中对对手使用。\n");
  # 
  #        if (!weapon || weapon->query("skill_type") != "sword")
  #                 return notify_fail("你必须在使用剑时才能使出「迅雷击」！\n");
  #                 
  #         //if (me->query_skill_mapped("parry") != "xuantie-jian")
  #         //        return notify_fail("你的基本招架必须是玄铁剑法时才能使出「迅雷击」！\n");
  # 
  #         if (me->query_skill_mapped("sword") != "xuantie-jian")
  #                 return notify_fail("你必须激发玄铁剑法才能使出「迅雷击」！\n");
  #                 
  #         if(me->query_skill("xuantie-jian", 1) < 160 )
  #                 return notify_fail("你的玄铁剑法还不够娴熟，使不出「迅雷击」。\n");
  # 
  #         if(me->query_skill("surge-force", 1) < 160 )
  #                 return notify_fail("你的怒海狂涛修为不够，使不出「迅雷击」。\n");
  # 
  #         if( (int)me->query_skill("force", 1) < 200 )
  #                 return notify_fail("你的内功等级不够，使不出「迅雷击」。\n");
  # 
  #         if( (int)me->query_str() < 45)
  #                 return notify_fail("你的膂力还不够，使不出「迅雷击」。\n");
  # 
  #         if( (int)me->query_dex() < 30)
  #                 return notify_fail("你的身法还不够，使不出「迅雷击」。\n");                                                                               
  # 
  #         if( (int)me->query("max_neili") < 2000 )
  #                 return notify_fail("你现在内力太弱，使不出「迅雷击」。\n");      
  # 
  #         if( (int)me->query("neili") < 900 )
  #                 return notify_fail("你现在真气太弱，使不出「迅雷击」。\n"); 
  # 
  #         me->add_temp("apply/str", z / 8);
  #         me->add_temp("apply/attack", j / 2); 
  #  
  #         msg = BLU "\n$N将手中的"+weapon->name()+"缓缓向$n一压，忽然剑光一闪， 一剑幻为三剑，宛如奔雷掣电攻向$n！\n\n"NOR;
  #         message_combatd(msg, me, target);
  #         
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #  
  # 
  #         me->add("neili", -350);
  #         
  #         me->add_temp("apply/str", -z / 8);
  #         me->add_temp("apply/attack", -j / 2);
  # 
  #         me->start_busy(3);
  #         if( !target->is_busy() )
  #                 target->start_busy(1);
  #         return 1;
  # }
end
