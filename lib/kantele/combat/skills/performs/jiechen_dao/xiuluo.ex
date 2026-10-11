defmodule Kantele.Combat.Skills.Performs.JiechenDao.Xiuluo do
  @moduledoc """
  perform「xiuluo」（source jiechen-dao/xiuluo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiechen-dao/xiuluo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiechen-dao")
    i = (div(Stats.skill(stats, "force"), 2) * (3 + Engine.rand(rng, 4)))
    count = 4

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
      Stats.skill(stats, "blade") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "hunyuan-yiqi") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jiechen-dao") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "jiechen-dao" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "force") != "hunyuan-yiqi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
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
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack"], "assign_refs": [{"i", "force"}], "busy_lines": ["me->start_busy(1+random(3));"], "level_gates": [{"blade", "180"}, {"hunyuan-yiqi", "140"}, {"jiechen-dao", "180"}], "map_gates": [{"blade", "jiechen-dao"}, {"force", "hunyuan-yiqi"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "1000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #        int i, jiali, count; 
  #         // string msg;
  #        object weapon;
  # 
  #        if( !target ) target = offensive_target(me);
  #        if( !target
  #                 || !target->is_character()
  #                 || !me->is_fighting(target)
  #                 || !living(target))
  #                 return notify_fail("「修罗焰」攻击只能对战斗中的对手使用。\n");
  #        if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你先找把刀再说吧！\n");
  # 
  #         if (me->query_skill_mapped("blade") != "jiechen-dao")
  #                 return notify_fail("你必须使用戒尘刀来施展「修罗焰」。\n");
  # 
  #         if(me->query_skill("jiechen-dao", 1) < 180 )
  #                 return notify_fail("你的戒尘刀火候还嫌不够，这「修罗焰」绝技不用也罢。\n");
  # 
  #         if(me->query_skill("blade", 1) < 180 )
  #                 return notify_fail("你的基本刀法还不够娴熟，使不出「修罗焰」绝技。\n");
  # 
  #         if( (int)me->query_skill("hunyuan-yiqi", 1) < 140 )
  #                 return notify_fail("你的心意气混元功等级不够，使不出「修罗焰」绝技。\n");
  # 
  #         if( (int)me->query_con() < 34)
  #                 return notify_fail("你的身体还不够强壮，强使「修罗焰」绝技是引火自焚！\n");
  # 
  #         if ( me->query_skill_mapped("force") != "hunyuan-yiqi")
  #            return notify_fail("你现在这内功平平无奇，如何使得出「修罗焰」绝技来！？\n");
  # 
  #         if (me->query("max_neili") < 3000)
  #            return notify_fail("你的内力修为不够，这「修罗焰」绝技不用也罢。\n");
  # 
  #         if (me->query("neili") < 1000)
  #            return notify_fail("以你目前的内力来看，这「修罗焰」绝技不用也罢。\n");
  # 
  #         me->add("neili", -300);
  # 
  #         message_vision(HIR "\n突然$N将手中武器从右手交到左手，运出十二分真力，脸色顿时通红，\n"
  #                            "宛如修罗降世。刀刃在内力的催动下立刻攻势大胜，\n"
  #                            "向着$n直劈而下！\n" NOR, me, target);
  # 
  #         i = me->query_skill("force") / 2 * (3+random(4));
  #         jiali = me->query("jiali");
  # 
  #         me->set("jiali", i);
  #         me->add_temp("apply/attack", jiali/2);
  # 
  #         count = 4;
  #         count += random(4);
  #         while (count --)
  #         {
  # 
  #               COMBAT_D->do_attack(me, target, me->query_temp("weapon"), 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -jiali/2);
  #         me->set("jiali", jiali);
  #         if(!me->query_temp("xiuluo")) me->add("neili", -300);
  #         else me->delete_temp("xiuluo");
  # 
  #         me->start_busy(1+random(3));
  #         return 1;
  # }
end
