defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Xin do
  @moduledoc """
  perform「摄心大法」（source jiuyin-shengong/perform/xin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 九阴神功>=280 →
  内功>=280 → 激发内功为九阴神功 → 内力>=500 → 目标存活。
  ap = 九阴神功 + 内功；dp = 武学常识 + 内功（均为目标侧）。
  命中：双方各忙乱 2+random(4)、扣 400 内力，目标受 jing 伤/创（ap/2+random(ap/4) /
  ap/2+random(ap/8)），并挂「摄心」临时标记（call_out 定时解除未建模，仅保留解除文案）。
  未命中：扣 200 内力、忙乱 1+random(2)。
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
  alias Kantele.Character.Vitals

  @perform_id "jiuyin-shengong/xin"
  @move_name "「摄心大法」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = lvl + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("jiuyin-shengong", 1) < 280)
  #          / if ((int)me->query_skill("force", 1) < 280)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jiuyin-shengong") < 280 ->
        {:error, "你九阴神功不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 280 ->
        {:error, "你内功根基不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "jiuyin-shengong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "force") != "jiuyin-shengong" do
      {:error, "你没有激发九阴神功为内功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # LPC: 起手文案
  defp apply_effect(conn, character, target) do
    lead =
      "\n$N猛然间尖啸一声，施展出九阴神功中的「摄心大法」。" <>
        "只见$N各种招式千奇百怪、变化多端，脸上喜怒哀乐，怪状百出。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(lead, [n1: character.name, n2: target.name]))
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
    # LPC remove_effs 文案（call_out 定时解除未建模，仅保留文案）
    _remove_eff = "猛然间你气血上冲，头昏胀痛之感顿然消去，精力逐渐集中起来。\n"

    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("martial-cognize", 1) + target->query_skill("force", 1);
    dp = Stats.skill(stats, "martial-cognize") + Stats.skill(stats, "force")

    if div(ap * 11, 20) + Engine.rand(rng, ap) > dp do
      # LPC: 命中
      jing_damage = div(ap, 2) + Engine.rand(rng, div(ap, 4))
      jing_wound = div(ap, 2) + Engine.rand(rng, div(ap, 8))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:jing, jing_damage)
        |> Vitals.wound(:jing, jing_wound)

      combat = character.meta.combat
      combat = Combat.start_busy(combat, 2 + Engine.rand(rng, 4))

      # LPC: target->set_temp("eff/jiuyin-shengong/xin", 1)
      # times 按目标武学常识分层（ap/10…8+random(7)）决定 call_out 时长，框架未建模
      combat = %{combat | temp: Map.put(combat.temp || %{}, "eff/jiuyin-shengong/xin", 1)}
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      # LPC: me->start_busy(2 + random(4)); me->add("neili", -400);
      Performs.feedback(attacker, 400, 2 + Engine.rand(rng, 4))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n登时觉得胸口苦闷之极，心神难以自制，喜怒哀乐竟全随着$N而变。顷刻之间，$n顿觉精力不济，头晕目眩。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: 未命中：me->add("neili", -200); me->start_busy(1 + random(2));
      Performs.feedback(attacker, 200, 1 + Engine.rand(rng, 2))

      # LPC 文案被 `+`（颜色续行）拆成两段字面量，E 侧须保持同样拆分
      miss =
        ["怒喝道：“尔等妖法，休想迷惑我！”。猛然间，招式陡快，竟将$N", "这招破去。\n"]
        |> Enum.join("")

      conn
      |> Broadcast.publish(Messages.interpolate(miss, bindings))
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIN "「" HIR "摄心大法" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # void remove_effs(object target);
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp;
  #     int times;
  # 
  #     me = this_player();
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/xin"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(XIN "只能在战斗中对对手使用。\n");
  # 
  #     if ((int)me->query_skill("jiuyin-shengong", 1) < 280)
  #         return notify_fail("你九阴神功不够娴熟，难以施展" XIN "。\n");
  # 
  #     if ((int)me->query_skill("force", 1) < 280)
  #         return notify_fail("你内功根基不够，难以施展" XIN "。\n");
  # 
  #     if (me->query_skill_mapped("force") != "jiuyin-shengong")
  #         return notify_fail("你没有激发九阴神功为内功，难以施展" XIN "。\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你现在的真气不够，难以施展" XIN "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "\n$N" HIM "猛然间尖啸一声，施展出九阴神功中的「" HIR "摄心大法" HIM "」。"
  #               "只见$N" HIM "各种招式千奇百怪、变化多端，脸上喜怒哀乐，怪状百出。\n" NOR;
  # 
  #     ap = me->query_skill("jiuyin-shengong", 1) + me->query_skill("force", 1);
  #     dp = target->query_skill("martial-cognize", 1) + target->query_skill("force", 1);
  # 
  #     if (ap * 11 / 20 + random(ap) > dp)
  #     {
  #         msg += HIG "$n" HIG "登时觉得胸口苦闷之极，心神难以自制，喜怒哀乐竟全随着$N" HIG
  #                    "而变。顷刻之间，$n" HIG "顿觉精力不济，头晕目眩。\n" NOR;
  # 
  #         me->start_busy(2 + random(4));
  #         me->add("neili", -400);
  #         target->start_busy(2 + random(4));
  #         target->receive_damage("jing", ap / 2 + random(ap / 4));
  #         target->receive_wound("jing", ap / 2 + random(ap / 8));
  #         target->set_temp("eff/jiuyin-shengong/xin", 1);
  # 
  #         if (target->query_skill("martial-cognize", 1) < 200)
  #             times = ap / 10 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 200)
  #             times = ap / 11 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 220)
  #             times = ap / 12 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 260)
  #             times = ap / 14 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 300)
  #             times = ap / 16 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 340)
  #             times = ap / 18 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 360)
  #             times = ap / 22 + random(6);
  #         if (target->query_skill("martial-cognize", 1) >= 380)
  #             times = ap / 30 + random(6);
  #         if (target->query_skill("martial-cognize", 1) > 400)
  #             times = 8 + random(7);
  #         remove_call_out("remove_effs");
  #         call_out("remove_effs", times, target);
  #     }
  #     else
  #     {
  #         msg += NOR + CYN "$n" NOR + CYN "怒喝道：“尔等妖法，休想迷惑我！”。猛然间，招式陡快，"
  #                                         "竟将$N" NOR +
  #                CYN "这招破去。\n" NOR;
  #         me->add("neili", -200);
  #         me->start_busy(1 + random(2));
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
  # 
  # void remove_effs(object target)
  # {
  #     if (!objectp(target) || !target->query_temp("eff/jiuyin-shengong/xin"))
  #         return;
  #     target->delete_temp("eff/jiuyin-shengong/xin");
  #     tell_object(target, HIW "猛然间你气血上冲，头昏胀痛之感顿然消去，精力逐渐集中起来。\n" NOR);
  #     return;
  # }
end
