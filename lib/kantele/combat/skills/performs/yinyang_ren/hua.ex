defmodule Kantele.Combat.Skills.Performs.YinyangRen.Hua do
  @moduledoc """
  perform「日月无华」（source yinyang-ren/hua.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinyang-ren/hua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinyang-ren")
    level = Stats.skill(stats, "yinyang-ren")

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
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "yinyang-ren" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "yinyang-ren" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 120, 2)
    result = Messages.interpolate("$n被耀眼的光芒所惑，心中惊疑不定，一时间不知如何应对！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}], "assign_refs": [{"level", "yinyang-ren"}], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 24 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "level_gates": [{"force", "200"}], "map_gates": [{"blade", "yinyang-ren"}, {"sword", "yinyang-ren"}], "remote_damage": false, "resource_gates": [{"neili", "150"}], "var_gates": [{"level", "180"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUA "「" HIY "日月无华" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         object weapon;
  #         int level;
  # 
  #         if (userp(me) && ! me->query("can_perform/yinyang-ren/hua"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUA "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" HUA "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         level = me->query_skill("yinyang-ren", 1);
  # 
  #         if (level < 180)
  #         return notify_fail("你阴阳刃法不够娴熟，难以施展" HUA "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yinyang-ren"
  #             && me->query_skill_mapped("blade") != "yinyang-ren")
  #                 return notify_fail("你没有激发阴阳刃法，难以施展" HUA "。\n");
  # 
  #     if ((int)me->query_skill("force") < 200)
  #         return notify_fail("你的内功火候不足，难以施展" HUA "。\n");
  # 
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不够，难以施展" HUA "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  # 
  #     msg = HIG "\n$N" HIG "使出阴阳刃法「" HIY "日月无华" HIG "」，手"
  #               "中" + weapon->name() + HIG "光芒瀑涨，刺眼眩目，日月为"
  #               "之失辉，刹那间光芒已盖向$n" HIG "。" NOR;
  #         message_sort(msg, me, target);
  # 
  #         me->add("neili", -120);
  #         if (level / 2 + random(level) > target->query_skill("dodge", 1))
  #         {
  #         msg = HIR "$n" HIR "被耀眼的光芒所惑，心中惊"
  #                       "疑不定，一时间不知如何应对！\n" NOR;
  #                 target->start_busy(level / 24 + 2);
  #                 me->start_busy(1);
  #     } else
  #         {
  #         msg = CYN "可是$n" CYN "看破了$N"
  #                       CYN "的企图，一丝不乱，应对自若。\n" NOR;
  #                 me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
