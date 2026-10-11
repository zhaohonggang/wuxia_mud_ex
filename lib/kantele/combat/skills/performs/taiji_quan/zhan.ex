defmodule Kantele.Combat.Skills.Performs.TaijiQuan.Zhan do
  @moduledoc """
  perform「粘字诀」（source taiji-quan/zhan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taiji-quan/zhan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taiji-quan")
    skill = Stats.skill(stats, "taiji-quan")
    ap = Stats.skill(stats, "unarmed")
    damage = (div(ap, 4) + Engine.rand(rng, div(ap, 4)))

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
          damage: damage,
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
    with :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "taiji-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 10}
    vitals = %{vitals | neili: vitals.neili - 30}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 30, 3)
    result = Messages.interpolate("$n登时便被套得跌跌撞撞，身不由主的立足不稳，犹如中酒昏迷。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}, {"neili", "-30"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"skill", "taiji-quan"}], "busy_lines": ["me->start_busy(2);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 50 + 1);", "me->start_busy(3);"], "map_gates": [{"unarmed", "taiji-quan"}], "prepared_gates": [{"unarmed", "taiji-quan"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHAN "「" HIW "粘字诀" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me)
  # {
  #         string msg;
  #         object /*weapon,*/ target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/taiji-quan/zhan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHAN "只能空手施展。\n");
  # 
  #         skill = me->query_skill("taiji-quan", 1);
  # 
  #         if (skill < 150)
  #                 return notify_fail("你的太极拳等级不够，难以施展" ZHAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" ZHAN "。\n");
  #  
  #         if (me->query_skill_mapped("unarmed") != "taiji-quan")
  #                 return notify_fail("你没有激发太极拳，难以施展" ZHAN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "taiji-quan")
  #                 return notify_fail("你现在没有准备使用太极拳，无法使用" ZHAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "连消带打，双手成圆形击出，这"
  #               "正是太极拳「圆转不断」四字的精意。只\n见$N"
  #               HIW "随即平圈、立圈、正圈、斜圈，一个跟着一"
  #               "个，一个个太极圆圈顿时笼\n罩$n" HIW "四面"
  #               "八方。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap * 4 / 3) > dp)
  #         {
  #                 me->add("neili", -30);
  #                 damage = ap / 4 + random(ap / 4);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "$n" HIR "登时便被套得跌跌撞撞，身"
  #                                            "不由主的立足不稳，犹如中酒昏迷。\n"
  #                                            NOR);
  #                 me->start_busy(2);
  #                 if (ap / 2 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 50 + 1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的企图，巧妙的拆招，没露半点破绽"
  #                        "。\n" NOR;
  #                 me->add("neili", -10);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
