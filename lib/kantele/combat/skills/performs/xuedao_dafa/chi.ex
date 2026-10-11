defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Chi do
  @moduledoc """
  perform「赤炼神刀」（source xuedao-dafa/chi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuedao-dafa/chi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuedao-dafa")
    count = 0
    i = 0

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
      Stats.skill(stats, "force") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuedao-dafa") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 1)
    result = Messages.interpolate("$N嗔目大喝，手中一势「赤炼神刀」迸出漫天血光，铺天盖地洒向$n。
霎时间$n只觉周围四处杀气弥漫，全身气血翻滚，甚难招架。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "apply_adds": ["attack"], "assign_refs": [{"count", "xuedao-dafa"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"force", "220"}, {"xuedao-dafa", "160"}], "map_gates": [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}], "remote_damage": false, "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CHI "「" HIR "赤炼神刀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int count;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuedao-dafa/chi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CHI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" CHI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 220)
  #                 return notify_fail("你的内功火候不够，难以施展" CHI "。\n");
  # 
  #         if ((int)me->query_skill("xuedao-dafa", 1) < 160)
  #                 return notify_fail("你的血刀大法还不到家，难以施展" CHI "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "xuedao-dafa")
  #                 return notify_fail("你没有激发血刀大法为内功，难以施展" CHI "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "xuedao-dafa")
  #                 return notify_fail("你没有激发血刀大法为刀法，难以施展" CHI "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" CHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "嗔目大喝，手中" + weapon->name() + HIW "一势「"
  #               HIR "赤炼神刀" HIW "」迸出漫天血光，铺天盖地洒向$n" HIW "。\n" NOR;
  # 
  #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
  #         {
  #                 msg += HIR "霎时间$n" HIR "只觉周围四处杀气弥漫，全身气血翻"
  #                        "滚，甚难招架。\n" NOR;
  #                 count = me->query_skill("xuedao-dafa", 1) / 4;
  #         } else
  #         {
  #                 msg += HIY "霎时间$n" HIY "只觉周围四处杀气弥漫，心底微微一"
  #                        "惊，连忙奋力招架。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add_temp("apply/attack", count);
  #         me->add("neili", -150);
  # 
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #     me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(6));
  #     return 1;
  # }
end
