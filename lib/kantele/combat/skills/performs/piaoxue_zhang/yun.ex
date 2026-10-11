defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Yun do
  @moduledoc """
  perform「云海明灯」（source piaoxue-zhang/yun.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "piaoxue-zhang/yun"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "piaoxue-zhang")

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
      Stats.skill(stats, "piaoxue-zhang") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "piaoxue-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
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
    Performs.feedback(attacker, 100, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(2 + random(3));"], "level_gates": [{"force", "200"}, {"piaoxue-zhang", "150"}], "map_gates": [{"strike", "piaoxue-zhang"}], "prepared_gates": [{"strike", "piaoxue-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YUN "「" HIW "云海明灯" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/piaoxue-zhang/yun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YUN "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") ||
  #             me->query_temp("secondary_weapon"))
  #                 return notify_fail("你必须空手才能施展" YUN "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，无法施展" YUN "。\n");
  # 
  #         if (me->query_skill("piaoxue-zhang", 1) < 150)
  #                 return notify_fail("你的飘雪穿云掌修为不够，无法施展" YUN "。\n");
  # 
  #         if (me->query("neili") < 200 || me->query("max_neili") < 2000)
  #                 return notify_fail("你的真气不够，无法施展" YUN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "piaoxue-zhang")
  #                 return notify_fail("你没有激发飘雪穿云掌，无法施展" YUN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "piaoxue-zhang")
  #                 return notify_fail("你没有准备使用飘雪穿云掌，无法施展" YUN "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬"
  #               "间连续攻出数招。\n" NOR;
  #     message_combatd(msg, me);
  # 
  #     me->add("neili", -100);
  # 
  #         // 第一招
  #         me->add_temp("apply/attack", 30);
  #           COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 第二招
  #         me->add_temp("apply/attack", 60);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 第三招
  #         me->add_temp("apply/attack", 90);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 消除攻击修正
  #         me->add_temp("apply/attack", -180);
  # 
  #     me->start_busy(2 + random(3));
  # 
  #     return 1;
  # }
end
