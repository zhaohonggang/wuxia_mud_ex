defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Bo do
  @moduledoc """
  perform「bo」（source bluesea-force/bo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "bluesea-force/bo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bluesea-force")

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
  defp check_gates(character), do: check_levels(character)

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "bluesea-force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
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
    Performs.feedback(attacker, 0, 1)
    result = Messages.interpolate("结果$p被$P逼得施展不开半点招式！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "bluesea-force"}, {"dp", "parry"}], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 45 + 2);", "me->start_busy(1);"], "level_gates": [{"bluesea-force", "100"}], "remote_damage": false}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // bo.c 碧海清波
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("碧海清波只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("bluesea-force", 1) < 100)
  #         return notify_fail("你的南海玄功不够深厚，不会使用碧海清波。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "掌力忽左忽右，形成一个个气旋，如波浪一般接连向$n"
  #               HIC "逼去！\n" NOR;
  # 
  #         ap = me->query_skill("bluesea-force", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         {
  #         msg += HIR "结果$p" HIR "被$P" HIR "逼得施展不开半点招式！\n" NOR;
  #         target->start_busy(ap / 45 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的掌势来路，"
  #                        "镇定自若，应对自如。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
