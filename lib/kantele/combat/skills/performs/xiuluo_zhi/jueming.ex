defmodule Kantele.Combat.Skills.Performs.XiuluoZhi.Jueming do
  @moduledoc """
  perform「jueming」（source xiuluo-zhi/jueming.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xiuluo-zhi/jueming"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xiuluo-zhi")
    ap = (Stats.skill(stats, "finger") + Stats.skill(stats, "force"))
    damage = (div(ap, 3) + Engine.rand(rng, div(ap, 3)))

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
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xiuluo-zhi") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "xiuluo-zhi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 350}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 350, 3)
    result = Messages.interpolate("只见$n一声惨叫，已被$N击中要害部位，只觉眼前一片
漆黑，身体摇摇欲坠！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-350"}], "assign_refs": [{"ap", "finger"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "level_gates": [{"force", "150"}, {"xiuluo-zhi", "100"}], "map_gates": [{"finger", "xiuluo-zhi"}], "remote_damage": true, "resource_gates": [{"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon; 
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「修罗绝命指」只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") ||
  #             me->query_temp("secondary_weapon"))
  #                 return notify_fail("你必须空手才能使用「修罗绝命指」！\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功的修为不够，不能使用「修罗绝命指」！\n");
  # 
  #         if (me->query_skill("xiuluo-zhi", 1) < 100)
  #                 return notify_fail("你的修罗指修为不够，目前不能使用「修罗绝命指」！\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法使用「修罗绝命指」！\n");
  # 
  #         if (me->query_skill_mapped("finger") != "xiuluo-zhi")
  #                 return notify_fail("你没有激发修罗指，不能使用「修罗绝命指」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "$N" HIB "忽然面露凶光，身形变的异常飘渺，在$n"
  #               HIB "的四周游走\n个不停，$n" HIB "正迷茫时，$N" HIB
  #               "突然近身，毫无声息的一指戳\n出！\n" NOR;
  # 
  #         ap = me->query_skill("finger") + me->query_skill("force");
  #         dp = target->query_skill("dodge") + target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 3 + random(ap / 3);
  #                 me->add("neili", -350);
  #                 me->start_busy(1);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                            HIR "只见$n" HIR "一声惨叫，已被$N" HIR
  #                                            "击中要害部位，只觉眼前一片\n漆黑，身体"
  #                                            "摇摇欲坠！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -150);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$n" CYN "看破了$N" CYN "的企图，轻"
  #                        "轻向后飘出数丈，躲过了这\n一致命的一击！\n"
  #                        NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
