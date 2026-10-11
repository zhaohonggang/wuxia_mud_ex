defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Ying do
  @moduledoc """
  perform「无影神刀」（source xuedao-dafa/ying.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuedao-dafa/ying"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuedao-dafa")

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
      Stats.skill(stats, "force") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuedao-dafa") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "xuedao-dafa" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "force") != "xuedao-dafa" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
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
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("$N一声狞笑，将手中的舞动如轮，刀锋激起层层血浪紧逼$n而去。
结果$p被$P逼得手忙脚乱，只能紧守门户，不敢擅动。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("blade") / 27 + 2);", "me->start_busy(1);"], "level_gates": [{"force", "160"}, {"xuedao-dafa", "120"}], "map_gates": [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YING "「" HIR "无影神刀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuedao-dafa/ying"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YING "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" YING "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("force") < 160)
  #                 return notify_fail("你的内功火候不够，难以施展" YING "。\n");
  # 
  #         if ((int)me->query_skill("xuedao-dafa", 1) < 120)
  #                 return notify_fail("你的血刀大法还不到家，难以施展" YING "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "xuedao-dafa")
  #                 return notify_fail("你没有激发血刀大法为内功，难以施展" YING "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "xuedao-dafa")
  #                 return notify_fail("你没有激发血刀大法为刀法，难以施展" YING "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，难以施展" YING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "一声狞笑，将手中的" + weapon->name() +
  #               WHT "舞动如轮，刀锋激起层层" HIR "血浪" NOR +
  #               WHT "紧逼$n" WHT "而去。\n" NOR;
  # 
  #         me->add("neili", -80);
  #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
  #         {
  #                 msg += HIR "结果$p" HIR "被$P" HIR "逼得手忙脚"
  #                        "乱，只能紧守门户，不敢擅动。\n" NOR;
  #                 target->start_busy((int)me->query_skill("blade") / 27 + 2);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图"
  #                        "，并不慌张，应对自如。\n" NOR;
  #                 me->start_busy(1);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
