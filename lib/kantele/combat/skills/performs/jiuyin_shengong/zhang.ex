defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhang do
  @moduledoc """
  perform「九阴神掌」（source jiuyin-shengong/zhang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiuyin-shengong/zhang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = Stats.skill(stats, "jiujin-shengong")
    count = 9
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
          ap: ap,
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
      Stats.skill(stats, "jiuyin-shengong") < 260 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "strike") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 320}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 320, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-320"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "jiujin-shengong"}, {"dp", "parry"}], "busy_lines": ["if (random(2) == 1 && !target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "level_gates": [{"jiuyin-shengong", "260"}, {"strike", "220"}], "prepared_gates": [{"strike", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "remote_damage": false, "var_gates": [{"i", "9"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhang.c 九阴神掌
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZHANG "「" HIM "九阴神掌" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp;
  #     int i, count;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhang"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(ZHANG "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("此招只能空手施展！\n");
  # 
  #     if ((int)me->query_skill("jiuyin-shengong", 1) < 260)
  #         return notify_fail("你的九阴神功不够深厚，不会使用" ZHANG "。\n");
  # 
  #     if ((int)me->query_skill("strike", 1) < 220)
  #         return notify_fail("你的基本掌法修为不够，不会使用" ZHANG "。\n");
  # 
  #     if (me->query_skill_prepared("unarmed") != "jiuyin-shengong" && me->query_skill_prepared("strike") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHANG "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "双掌一错，幻化出无数掌影，层层叠荡向$n" HIY "逼去！\n" NOR;
  #     message_combatd(msg, me, target); //修正pfm描述信息显示时间错误 by MK
  # 
  #     ap = me->query_skill("jiujin-shengong", 1);
  #     dp = target->query_skill("parry", 1);
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         // count = ap / 7;
  #         count = ap / 5;
  # 
  #     else
  #         count = 9;
  # 
  #     me->add_temp("apply/attack", count);
  #     for (i = 0; i < 9; i++)
  #     {
  #         if (!me->is_fighting(target))
  #             break;
  # 
  #         if (random(2) == 1 && !target->is_busy())
  #             target->start_busy(1);
  # 
  #         COMBAT_D->do_attack(me, target, 0, );
  #     }
  #     me->start_busy(2 + random(4));
  #     me->add("neili", -320);
  # 
  #     me->add_temp("apply/attack", -count);
  # 
  #     return 1;
  # }
end
