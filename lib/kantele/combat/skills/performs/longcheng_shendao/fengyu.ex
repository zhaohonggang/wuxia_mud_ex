defmodule Kantele.Combat.Skills.Performs.LongchengShendao.Fengyu do
  @moduledoc """
  perform「fengyu」（source longcheng-shendao/fengyu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "longcheng-shendao/fengyu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longcheng-shendao")
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "longcheng-shendao") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 270 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
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
    Performs.feedback(attacker, 120, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}], "apply_adds": ["attack"], "assign_refs": [{"lvl", "longcheng-shendao"}], "busy_lines": ["me->start_busy(1 + random(5));"], "level_gates": [{"force", "150"}, {"longcheng-shendao", "120"}], "remote_damage": false, "resource_gates": [{"neili", "270"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fengyu.c 风雨交加
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/longcheng-shendao/fengyu"))
  #                 return notify_fail("你不会使用「风雨交加」。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「风雨交加」只能对战斗中的对手使用。\n");
  # 
  #     if (!objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("施展「风雨交加」手中必须拿着一把刀！\n");
  # 
  #     if ((int)me->query("neili") < 270)
  #         return notify_fail("你的真气不够，无法施展「风雨交加」！\n");
  # 
  #     if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你的内功火候不够，无法施展「风雨交加」！\n");
  # 
  #     if ((lvl = (int)me->query_skill("longcheng-shendao", 1)) < 120)
  #         return notify_fail("你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() + HIC
  #               "如雨点一般向$n" HIC "打去，$n" HIC "如同小舟一般在刀雨中漂泊不定。\n" NOR;
  # 
  #         if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
  #         {
  #                 msg += HIY "这阵刀势变化莫测，$n" HIY "顿时觉得眼花缭乱，无法抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -120);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #     me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  # 
  #     return 1;
  # }
end
