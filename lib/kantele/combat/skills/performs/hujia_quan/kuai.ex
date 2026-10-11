defmodule Kantele.Combat.Skills.Performs.HujiaQuan.Kuai do
  @moduledoc """
  perform「奔拳快打」（source hujia-quan/kuai.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "hujia-quan/kuai"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hujia-quan")

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
      Stats.skill(stats, "force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "hujia-quan") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "cuff") != "hujia-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 80 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 40}
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
    Performs.feedback(attacker, 40, 2)
    result = Messages.interpolate("结果$n无法分清$N招式中的虚实，不由手忙脚乱。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-40"}], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("cuff") / 25 + 2);", "me->start_busy(2);"], "level_gates": [{"force", "100"}, {"hujia-quan", "80"}], "map_gates": [{"cuff", "hujia-quan"}], "prepared_gates": [{"cuff", "hujia-quan"}], "remote_damage": false, "resource_gates": [{"neili", "80"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KUAI "「" WHT "奔拳快打" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/hujia-quan/kuai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(KUAI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(KUAI "只能空手施展。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #     if ((int)me->query_skill("force") < 100)
  #         return notify_fail("你的内功火候不足，难以施展" KUAI "。\n");
  # 
  #     if ((int)me->query_skill("hujia-quan", 1) < 80)
  #         return notify_fail("你的胡家拳法不够娴熟，难以施展" KUAI "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "hujia-quan")
  #                 return notify_fail("你没有激发胡家拳法，难以施展" KUAI "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "hujia-quan")
  #                 return notify_fail("你没有准备胡家拳法，难以施展" KUAI "。\n");
  # 
  #         if (me->query("neili") < 80)
  #                 return notify_fail("你现在真气不够，难以施展" KUAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = WHT "$N" WHT "纵步上前，拳招迭出，疾如奔雷，霎时已向$n" WHT "攻出数拳。\n" NOR;
  # 
  #         me->add("neili", -40);
  #     if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
  #         {
  #         msg += HIR "结果$n" HIR "无法分清$N" HIR "招式中的虚实，"
  #                        "不由手忙脚乱。\n" NOR;
  #         target->start_busy((int)me->query_skill("cuff") / 25 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的虚招，轻轻一闪，"
  #                        "避开了这骤雨般的拳影。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
