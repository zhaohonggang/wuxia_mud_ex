defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Sheng do
  @moduledoc """
  perform「无声无息」（source kuihua-mogong/sheng.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 目标未忙乱 →
  葵花魔功>=200 → 内力上限>=3000 → 内力>=200 → 激发 dodge 为葵花魔功 →
  目标存活。
  ap = 葵花魔功*3/2 + 武学修养；dp = 目标闪避 + 目标武学修养。
  命中判定：ap*3/5 + random(ap) > dp。无伤害。
  命中：目标忙乱 ap/30+2，扣 120 内力、忙乱 1；
  未命中：扣 80 内力、忙乱 1+random(2)。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "kuihua-mogong/sheng"
  @move_name "「无声无息」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    ap = div(Stats.skill(stats, "kuihua-mogong") * 3, 2) + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_target_busy(target),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 目标忙乱取引用快照 meta 的 combat.busy（缺 meta 时按未忙处理）
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧！\n"}
    else
      :ok
    end
  end

  defp busy?(target) do
    case target do
      %{meta: %{combat: %{busy: busy}}} -> busy > 0
      _ -> false
    end
  end

  # LPC: if ((int)me->query_skill("kuihua-mogong", 1) < 200)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kuihua-mogong") < 200 do
      {:error, "你的葵花魔功不够深厚，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 3000) / if (me->query("neili") < 200)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 200 -> {:error, "你的真气不够，无法施展#{@move_name}！\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_skill_mapped("dodge") != "kuihua-mogong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "dodge") != "kuihua-mogong" do
      {:error, "你还没有激发葵花魔功为轻功，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIR "$N" HIR "身子忽进忽退，身形诡秘异常，在$n" HIR "身边飘忽不定。\n" NOR;
  # （C 侧各段字面量仅由颜色宏/空白分隔，合并为同一条文案）
  defp apply_effect(conn, character, target) do
    msg = "$N身子忽进忽退，身形诡秘异常，在$n身边飘忽不定。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap * 3 / 5 + random(ap) > dp)
    if div(ap * 3, 5) + Engine.rand(rng, ap) > dp do
      # LPC: target->start_busy(ap / 30 + 2); me->add("neili", -120); me->start_busy(1);
      combat = Combat.start_busy(character.meta.combat, div(ap, 30) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}
      Performs.feedback(attacker, 120, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$p只能紧守门户，不敢妄自出击！\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(1 + random(2)); me->add("neili", -80);
      Performs.feedback(attacker, 80, 1 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$P的身法，并没有受到任何影响。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // sheng.c 无声无息
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define XI "「" HIW "无声无息" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/sheng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(XI "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("kuihua-mogong", 1) < 200)
  #         return notify_fail("你的葵花魔功不够深厚，不会使用" XI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，难以施展" XI "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，无法施展" XI "！\n");
  # 
  #         if (me->query_skill_mapped("dodge") != "kuihua-mogong")
  #                 return notify_fail("你还没有激发葵花魔功为轻功，无法施展" XI "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "身子忽进忽退，身形诡秘异常，在$n"
  #               HIR "身边飘忽不定。\n" NOR;
  # 
  #         ap = me->query_skill("kuihua-mogong", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("dodge") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #     if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #         msg += HIR "结果$p" HIR "只能紧守门户，不敢妄自出击！\n" NOR;
  #         target->start_busy(ap / 30 + 2);
  #                 me->add("neili", -120);
  #                 me->start_busy(1);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的身法，并没"
  #                        "有受到任何影响。\n" NOR;
  #         me->start_busy(1 + random(2));
  #                 me->add("neili", -80);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
