defmodule Kantele.Combat.Skills.Performs.ChanhunSuo.Suo do
  @moduledoc """
  锁魂势「suo」（对照 `kungfu/skill/chanhun-suo/suo.c`，inherit F_SSERVER）

  缠魂锁法单体攻击：要求内力 >= 150、内功 force >= 100、chanhun-suo >= 70、
  武器为鞭(whip) 且已激发映射；按双方 combat_exp 判定命中，命中后目标陷入忙乱。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "chanhun-suo/suo"
  @move_name "「锁魂势」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         :ok <- check_weapon(combat),
         {:ok, target} <- target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_target_busy(target),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "chanhun-suo") < 70 do
      {:error, "你的缠魂索功力太浅，使不了#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功火候不够，使不了#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, "#{target.name}目前正自顾不暇，放胆攻击吧！\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "chanhun-suo" do
      :ok
    else
      {:error, "你没有激发缠魂索法，使不了#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不足，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp target_busy?(%{meta: %{combat: %{busy: busy}}}), do: busy > 0
  defp target_busy?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = HIR "$N" HIR "一声阴笑，使出缠魂索锁魂绝迹，挥舞出满天鞭影，将$n"
    #            HIR "全全笼罩！\n\n" NOR;
    # 注：LPC 仅校验 neili>=150，并不扣内力。
    start_msg = "$N一声阴笑，使出缠魂索锁魂绝迹，挥舞出满天鞭影，将$n全全笼罩！\n\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = stats.combat_exp
    dp = div(target.meta.stats.combat_exp, 2)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
    hit = Engine.rand(rng, ap) > dp

    if hit do
      # LPC: target->start_busy((int)me->query_skill("whip") / 22 + 1);
      #      me->start_busy(1 + random(2));
      target_busy_rounds = div(Stats.skill(attacker.meta.stats, "whip"), 22) + 1
      character_combat = Combat.start_busy(character.meta.combat, target_busy_rounds)
      character = %{character | meta: %{character.meta | combat: character_combat}}

      # LPC: "结果$n" "被这排山倒海般的攻击攻了个措手不及，陷如困境，完全无法脱身！\n"
      hit_msg = "结果$n被这排山倒海般的攻击攻了个措手不及，陷如困境，完全无法脱身！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 2))
    else
      # LPC: "可是$p" "看破了$P" "的企图，往后一纵，逃开了攻势。。\n"
      #      me->start_busy(4);
      miss_msg = "可是$p看破了$P的企图，往后一纵，逃开了攻势。。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 4)
    end

    conn
    |> put_character(character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # ===== 原始 LPC 源码（逐行保留，供核对；移植稳定后删除）=====
  # #include <ansi.h>
  #
  # inherit F_SSERVER;
  #
  # #define SUO "「" HIR "锁魂势" NOR "」"
  #
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #
  #        if (userp(me) && ! me->query("can_perform/chanhun-suo/suo"))
  #                return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #        if (! target) target = offensive_target(me);
  #
  #        if (! objectp(weapon = me->query_temp("weapon")) ||
  #              (string)weapon->query("skill_type") != "whip")
  #                return notify_fail("你使用的武器不对。\n");
  #
  #        if (! target || ! me->is_fighting(target))
  #                return notify_fail(SUO "只能对战斗中对对手使用。\n");
  #
  #        if ((int)me->query_skill("chanhun-suo",1) < 70)
  #                return notify_fail("你的缠魂索功力太浅，使不了" SUO "。\n");
  #
  #        if ((int)me->query_skill("force", 1) < 100)
  #                return notify_fail("你的内功火候不够，使不了" SUO "。\n");
  #
  #        if (target->is_busy())
  #                return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  #
  #        if (me->query_skill_mapped("whip") != "chanhun-suo")
  #                return notify_fail("你没有激发缠魂索法，使不了" SUO "。\n");
  #
  #        if (me->query("neili") < 150)
  #                return notify_fail("你内力不足，无法施展" SUO "。\n");
  #
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #        msg = HIR "$N" HIR "一声阴笑，使出缠魂索锁魂绝迹，挥舞出满天鞭影，将$n"
  #              HIR "全全笼罩！\n\n" NOR;
  #
  #        if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #        {
  #                msg += HIY "结果$n" HIY "被这排山倒海般的攻击攻了个措手不及，陷如困境，完全无法脱身！\n" NOR;
  #                target->start_busy((int)me->query_skill("whip") / 22 + 1);
  #                me->start_busy(1 + random(2));
  #        } else
  #        {
  #                msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，往后一纵，逃开了攻势。。\n" NOR;
  #                me->start_busy(4);
  #        }
  #        message_combatd(msg, me, target);
  #        return 1;
  # }
end
