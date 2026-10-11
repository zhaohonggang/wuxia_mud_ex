defmodule Kantele.Combat.Skills.Performs.WaiBagua.Zhen do
  @moduledoc """
  perform「八卦震」（source wai-bagua/zhen.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "wai-bagua/zhen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "wai-bagua")

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "wai-bagua") < 60 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 50}
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
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("结果$n微微一楞，没有看破招中奥妙，$N双掌正好拍在胸前。
:内伤@?", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"damage", "wai-bagua"}], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "level_gates": [{"force", "100"}, {"wai-bagua", "60"}], "remote_damage": true, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" WHT "八卦震" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/wai-bagua/zhen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(ZHEN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功火候不足，难以施展" ZHEN  "。\n");
  # 
  #         if ((int)me->query_skill("wai-bagua", 1) < 60)
  #                 return notify_fail("你的外八卦不够娴熟，难以施展" ZHEN  "。\n");
  #                                 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" ZHEN  "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "深吸一口气，双掌交错，一招「八卦震」平平拍出，企"
  #               "图以内力震伤$n" WHT "。\n" NOR;
  #         me->add("neili", -50);
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 me->start_busy(3);
  #                 target->start_busy(random(3));
  # 
  #                 damage = (int)me->query_skill("wai-bagua", 1);
  #                 damage = damage / 2 + random(damage / 2);
  #                 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "结果$n" HIR "微微一楞，没有看破招"
  #                                            "中奥妙，$N" HIR "双掌正好拍在胸前。\n"
  #                                            NOR ":内伤@?");
  #         } else 
  #         {
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，并没有上当。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
