defmodule Kantele.Combat.Skills.Performs.KuangfengBlade.Kuang do
  @moduledoc """
  perform「kuang」（source kuangfeng-blade/kuang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "kuangfeng-blade/kuang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuangfeng-blade")

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
      Stats.skill(stats, "kuangfeng-blade") < 70 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 60}
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
    Performs.feedback(attacker, 60, 2)
    result = Messages.interpolate("只见$n已被$N切得体无完肤，血如箭般由全身喷射而出！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-60"}], "assign_refs": [{"damage", "blade"}], "busy_lines": ["me->start_busy(2);", "target->start_busy(3);"], "level_gates": [{"kuangfeng-blade", "70"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // kuang.c -「狂风二十一式」
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能对战斗中的对手使用「狂风二十一式」。\n");
  # 
  #         if ((int)me->query_skill("kuangfeng-blade", 1) < 70)
  #                 return notify_fail("你目前功力还使不出「狂风二十一式」。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -60);
  #         msg = HIC "$N" HIC "淡然一笑，本就快捷绝伦的刀法骤然变"
  #               "得更加凌厉！就在这一瞬之间，$N" HIC "已劈出二十"
  #               "一刀！\n刀夹杂着风，风里含着刀影！$n"
  #               HIC "只觉得心跳都停止了！\n" NOR;
  #         me->start_busy(2);
  # 
  #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 target->start_busy(3);
  #                 damage = (int)me->query_skill("blade");
  #                 damage = damage / 2 + random(damage / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40, 
  #                                            HIR "只见$n" HIR "已被$N" HIR
  #                                            "切得体无完肤，血如箭般由全身喷射而出！\n" NOR);
  #         } else
  #         {
  #                 msg += HIC "可是$p" HIC "急忙抽身躲开，使$P"
  #                        HIC "这招没有得逞。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
