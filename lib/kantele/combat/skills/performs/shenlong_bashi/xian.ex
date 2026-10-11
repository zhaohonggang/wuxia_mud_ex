defmodule Kantele.Combat.Skills.Performs.ShenlongBashi.Xian do
  @moduledoc """
  perform「xian」（source shenlong-bashi/xian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shenlong-bashi/xian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shenlong-bashi")

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
      Stats.skill(stats, "force") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shenlong-bashi") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hand") != "shenlong-bashi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 125}
    vitals = %{vitals | neili: vitals.neili - 30}
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
    Performs.feedback(attacker, 30, 2)
    result = Messages.interpolate("$p左遮右挡，却没能挡住$P这看似无赖的招数，结果被$P重重的击中，哇的吐了一口鲜血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-125"}, {"neili", "-30"}], "assign_refs": [{"damage", "force"}], "busy_lines": ["me->start_busy(2);", "target->start_busy(1);"], "level_gates": [{"force", "80"}, {"shenlong-bashi", "100"}], "map_gates": [{"hand", "shenlong-bashi"}], "remote_damage": true, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // xian.c 神龙初现
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("神龙初现只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("shenlong-bashi", 1) < 100)
  #                 return notify_fail("你的神龙八式手法还不够娴熟，不能使用神龙初现。\n");
  # 
  #         if ((int)me->query_skill("force") < 80)
  #                 return notify_fail("你的内功火候不够，不能使用神龙初现。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在真气不够，不能使用神龙初现。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "shenlong-bashi")
  #                 return notify_fail("你没有激发神龙八式手法，不能使用神龙初现。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "脚下轻浮，踉踉跄跄，似倒非倒，跌跌撞撞的冲向$n"
  #               HIG "，同时伸手就是一招，诡秘之极。\n" NOR;
  # 
  #         me->start_busy(2);
  #         if (random(me->query_skill("hand")) > target->query_skill("parry") / 2)
  #         {
  #                 damage = (int)me->query_skill("force");
  #                 damage = damage / 2 + random(damage / 2);
  # 
  #                 target->start_busy(1);
  #                 me->add("neili", -125);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                            HIR "$p" HIR "左遮右挡，却没能挡住$P" HIR "这看似无赖"
  #                                    "的招数，结果被$P" HIR "重重的击中，哇的吐了一口鲜血。\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，巧妙的挡住了$P"
  #                        CYN "的进攻。\n" NOR;
  #                 me->add("neili", -30);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
