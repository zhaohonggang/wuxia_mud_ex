defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Xin do
  @moduledoc """
  perform「摄心大法」（source jiuyin-shengong/xin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiuyin-shengong/xin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = (Stats.skill(stats, "jiuyin-shengong") + Stats.skill(stats, "force"))
    times = (8 + Engine.rand(rng, 7))

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
      Stats.skill(stats, "force") < 280 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jiuyin-shengong") < 280 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "martial-cognize") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "jiuyin-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 400}
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
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :jing, (div(ap, 2) + Engine.rand(rng, div(ap, 4))))
          vitals = Vitals.wound(vitals, :jing, (div(ap, 2) + Engine.rand(rng, div(ap, 8))))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 400, 1)
    result = if hit, do: Messages.interpolate("$N猛然间尖啸一声，施展出九阴神功中的「摄心大法」。只见$N各种招式千奇百怪、变化多端，脸上喜怒哀乐，怪状百出。", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "assign_refs": [{"ap", "jiuyin-shengong"}, {"dp", "martial-cognize"}], "busy_lines": ["me->start_busy(2 + random(4));", "target->start_busy(2 + random(4));", "me->start_busy(1 + random(2));"], "level_gates": [{"force", "280"}, {"jiuyin-shengong", "280"}, {"martial-cognize", "200"}], "map_gates": [{"force", "jiuyin-shengong"}], "remote_damage": false, "resource_gates": [{"neili", "500"}]}

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
