defmodule Kantele.Combat.Skills.Performs.FeihuaZhang.Fei do
  @moduledoc """
  perform「掌打飞花」（source feihua-zhang/fei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "feihua-zhang/fei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "feihua-zhang")
    ap = Stats.skill(stats, "strike")
    attack_time = 6
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
      Stats.skill(stats, "feihua-zhang") < 40 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "feihua-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    result = Messages.interpolate("结果$n目不暇接，顿时被$N掌风所困，顿时阵脚大乱。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["if (! target->is_busy() && random(3) == 1)", "target->start_busy(1);", "me->start_busy(1 + random(attack_time));"], "level_gates": [{"feihua-zhang", "40"}], "map_gates": [{"strike", "feihua-zhang"}], "prepared_gates": [{"strike", "feihua-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEI "「" HIG "掌打飞花" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int attack_time, i;
  # 
  #         if (userp(me) && ! me->query("can_perform/feihua-zhang/fei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FEI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(FEI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("feihua-zhang", 1) < 40)
  #                 return notify_fail("你飞花掌法不够娴熟，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "feihua-zhang")
  #                 return notify_fail("你没有激发飞花掌法，难以施展" FEI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "feihua-zhang")
  #                 return notify_fail("你没有准备飞花掌法，难以施展" FEI "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不够，难以施展" FEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双掌陡然连续拍出，刚中带柔，一招"
  #               "「" HIG "掌打飞花" HIC "」，双掌带风，已将$n"
  #               HIC "笼罩在掌风之中。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #     if (random(ap) > dp / 2)
  #     {
  #         msg = HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌"
  #                       "风所困，顿时阵脚大乱。\n" NOR;
  #                 me->add_temp("apply/attack", 10);
  #         } else
  #         {
  #                 msg = HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
  #                       "内劲所至，刚柔并济，也只得小心抵挡。\n" NOR;
  #         }
  #     message_vision(msg, me, target);
  # 
  #         attack_time += 3 + random(ap / 40);
  # 
  #         if (attack_time > 6)
  #                 attack_time = 6;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 if (! target->is_busy() && random(3) == 1)
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  #     me->start_busy(1 + random(attack_time));
  #         me->add_temp("apply/attack", -10);
  # 
  #     return 1;
  # }
end
