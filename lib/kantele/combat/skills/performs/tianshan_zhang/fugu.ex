defmodule Kantele.Combat.Skills.Performs.TianshanZhang.Fugu do
  @moduledoc """
  perform「如蛆附骨」（source tianshan-zhang/fugu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tianshan-zhang/fugu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tianshan-zhang")
    ap = Stats.skill(stats, "staff")

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
         :ok <- check_mapped(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "tianshan-zhang") < 60 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "staff") != "tianshan-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 0, 1)
    result = Messages.interpolate("结果$n被$N吓得惊慌失措，一时间手忙脚乱，难以应对！
可是$n看破了$N的企图，轻轻一退，闪去了$N的追击。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "staff"}, {"dp", "dodge"}], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("staff") / 25 + 2);", "me->start_busy(1);"], "level_gates": [{"tianshan-zhang", "60"}], "map_gates": [{"staff", "tianshan-zhang"}], "remote_damage": false}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fugu.c 如蛆附骨
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define GU "「" HIW "如蛆附骨" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/tianshan-zhang/fugu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(GU "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  #                 
  #         if ((int)me->query_skill("tianshan-zhang", 1) < 60)
  #                 return notify_fail("你的天山杖法不够娴熟，不会使用" GU "。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "tianshan-zhang")
  #                 return notify_fail("你没有激发天山杖法，使不了" GU "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "桀桀奸笑，手中的" + weapon->name() +
  #               HIG "就像影子一般袭向$n。\n" NOR;
  # 
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("dodge");
  #         if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 msg += HIR "结果$n" HIR "被$N" HIR "吓得惊慌失措，"
  #                        "一时间手忙脚乱，难以应对！\n" NOR;
  #                 target->start_busy((int)me->query_skill("staff") / 25 + 2);
  #         } else
  #         {
  #                 msg += "可是$n" HIR "看破了$N" HIR "的企图，"
  #                        "轻轻一退，闪去了$N" HIR "的追击。\n" NOR;
  #                 me->start_busy(1);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
