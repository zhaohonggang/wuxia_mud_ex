defmodule Kantele.Combat.Skills.Performs.HuagongDafa.Hua do
  @moduledoc """
  exert「hua」（source huagong-dafa/hua.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：房间非 no_fight → 目标存在（非自身）→ 目标种族为人类 →
  自身非忙 → 空手 → 化功大法>=100 → 真气>=120 →
  目标 neili>=10 且 max_neili>=10 → 目标 max_neili <= 自身 max_neili*4/3。
  起手广播后若目标太玄功>0 则反弹并中止；否则进入内力对抗
  `sp/2 + random(sp) > random(dp)`（`sp`=自身 force+dodge，`dp`=目标 force+dodge）：
  成功则目标 max_neili 减少 `random(4) + (化功-90)/8`（下限 0）、
  目标 busy 2（若非忙），攻击方忙乱 `2+random(2)`、扣 100 真气；
  失手则广播化解文案，攻击方忙乱 `2+random(3)`、扣 100 真气。

  差异（TODO(migrate)）：
  - 房间 `no_fight` 经 `character.meta.room` 读取（同 `hamagong/tan.ex`）；
  - `me->want_kill(target)` / `target->kill_ob(me)` 的敌对标记未在引擎侧建模；
  - 敌人列表为引用快照（`%{id,pid,name,room_id}`），`meta` 可能缺失；
    缺 meta 时目标属性门槛按 `.c` 默认（通过）处理，避免攻击方命令崩溃
    （同 `beiming_shengong/suck.ex` 的既有偏差）；
  - `tell_object(target, …)` 由房间广播承担（可接受偏差）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "huagong-dafa/hua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huagong-dafa")

    with :ok <- check_no_fight(character),
         {:ok, target} <- find_target(character),
         :ok <- check_race(target),
         :ok <- check_not_busy(character),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_target_neili(target),
         :ok <- check_target_max_neili(character, target) do
      apply_effect(conn, character, target, lvl, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("在这里不能攻击他人。\n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if (target == me) target = offensive_target(me);
  #      if (! objectp(target)) return notify_fail("你要化谁的内力？\n");
  defp find_target(character) do
    case character.meta.combat.enemies do
      [%{id: id} = target | _] when id != character.id -> {:ok, target}
      _ -> {:error, "你要化谁的内力？\n"}
    end
  end

  # LPC: if (target->query("race") != "人类") return notify_fail("搞错了！只有人才能有内力！\n");
  defp check_race(target) do
    if Map.get(target_meta(target), :race, "人类") == "人类" do
      :ok
    else
      {:error, "搞错了！只有人才能有内力！\n"}
    end
  end

  # LPC: if (me->is_busy()) return notify_fail("你现在正忙，无法化他人内力。\n");
  defp check_not_busy(character) do
    if Combat.busy?(character.meta.combat) do
      {:error, "你现在正忙，无法化他人内力。\n"}
    else
      :ok
    end
  end

  # LPC: if (objectp(me->query_temp("weapon"))) return notify_fail("你必须空手才能施用化功大法！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你必须空手才能施用化功大法！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("huagong-dafa", 1) < 100)
  #        return notify_fail("你的化功大法功力不够，不能施展！\n");
  defp check_levels(stats) do
    if Stats.skill(stats, "huagong-dafa") < 100 do
      {:error, "你的化功大法功力不够，不能施展！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 120) return notify_fail("你的内力不够，不能施展化功大法。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 120 do
      {:error, "你的内力不够，不能施展化功大法。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)target->query("neili") < 10 || (int)target->query("max_neili") < 10)
  #        return notify_fail(target->name() + "已然内力涣散，不必再化了。\n");
  defp check_target_neili(target) do
    vitals = target_vitals(target)

    if Map.get(vitals, :neili, 10) < 10 or Map.get(vitals, :max_neili, 10) < 10 do
      {:error, target.name <> "已然内力涣散，不必再化了。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)target->query("max_neili") > (int)me->query("max_neili") * 4 / 3)
  #        return notify_fail(target->name() + "的内功修为远胜于你，你无法化他的内力！\n");
  defp check_target_max_neili(character, target) do
    my_max = character.meta.vitals.max_neili
    tg_max = Map.get(target_vitals(target), :max_neili, 0)

    if tg_max > div(my_max * 4, 3) do
      {:error, target.name <> "的内功修为远胜于你，你无法化他的内力！\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target, lvl, rng) do
    # LPC: message_combatd(HIR "$N" HIR "全身骨节爆响，双臂暴长数尺，手掌"
    #                "刷的一抖，粘向$n！\n" NOR, me, target);
    conn =
      Broadcast.publish(conn, "$N全身骨节爆响，双臂暴长数尺，手掌刷的一抖，粘向$n！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: if (target->query_skill("taixuan-gong", 1)) { message_sort(HIG …); return 1; }
    if taixuan?(target) do
      conn
      |> Broadcast.publish(
        "\n$N刚将手掌接触到$n肌肤，猛然觉得一股无比强大的内劲反压回来，化功大法的内力却犹如石沉大海。$N大吃一惊，连忙将手缩回，再也不敢接近。\n",
        n1: character.name,
        n2: target.name
      )
      |> assign(:prompt, false)
    else
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          sp: Stats.skill(character.meta.stats, "force") + Stats.skill(character.meta.stats, "dodge"),
          rng: rng
        }
      })

      assign(conn, :prompt, false)
    end
  end

  # LPC: if (target->query_skill("taixuan-gong", 1))
  defp taixuan?(target) do
    stats = Map.get(target_meta(target), :stats) || %{}
    Stats.skill(stats, "taixuan-gong") > 0
  end

  defp target_meta(target), do: Map.get(target, :meta) || %{}

  defp target_vitals(target), do: Map.get(target_meta(target), :vitals) || %{}

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    do_resolve_incoming(conn, character, attacker, data)
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    sp = max(Map.get(data, :sp, 0), 1)
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_skill("dodge");
    dp = max(Stats.skill(stats, "force") + Stats.skill(stats, "dodge"), 1)

    # LPC: if ((sp / 2 + random(sp) > random(dp)) || ! living(target))
    if div(sp, 2) + Engine.rand(rng, sp) > Engine.rand(rng, dp) or character.meta.combat.dead do
      # LPC: tell_object(target, HIR "你只觉天顶骨裂，全身功力贯脑而出，如融雪般消失得无影无踪！\n" NOR);
      #      target->add("max_neili", -1 * (random(4) + (huagong-dafa - 90) / 8));
      #      if (target->query("max_neili") < 1) target->set("max_neili", 0);
      #      if (! target->is_busy()) target->start_busy(2);
      amount = Engine.rand(rng, 4) + div(lvl - 90, 8)
      vitals = %{character.meta.vitals | max_neili: max(character.meta.vitals.max_neili - amount, 0)}

      combat =
        if Combat.busy?(character.meta.combat) do
          character.meta.combat
        else
          Combat.start_busy(character.meta.combat, 2)
        end

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      # LPC: me->start_busy(2 + random(2)); me->add("neili", -100);
      Performs.feedback(attacker, 100, 2 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish("你只觉天顶骨裂，全身功力贯脑而出，如融雪般消失得无影无踪！\n")
      |> put_character(character)
    else
      # LPC: message_combatd(HIY "可是$p" HIY "看破了$P" HIY "的企图，内力猛地一震，借势溜"
      #                "了开去。\n" NOR, me, target);
      #      me->start_busy(2 + random(3)); me->add("neili", -100);
      Performs.feedback(attacker, 100, 2 + Engine.rand(rng, 3))

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$P的企图，内力猛地一震，借势溜了开去。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // hua.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #     int sp, dp;
  #     int my_max, tg_max;
  # 
  #     if (target == me) target = offensive_target(me);
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("在这里不能攻击他人。\n");
  # 
  #     if (! objectp(target))
  #         return notify_fail("你要化谁的内力？\n");
  # 
  #     if (target->query("race") != "人类")
  #         return notify_fail("搞错了！只有人才能有内力！\n");
  # 
  #         if (me->is_busy())
  #                 return notify_fail("你现在正忙，无法化他人内力。\n");
  # 
  #         my_max = me->query("max_neili");
  #         tg_max = target->query("max_neili");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #         return notify_fail("你必须空手才能施用化功大法！\n");
  # 
  #     if ((int)me->query_skill("huagong-dafa", 1) < 100)
  #         return notify_fail("你的化功大法功力不够，不能施展！\n");
  # 
  #     if ((int)me->query("neili") < 120)
  #         return notify_fail("你的内力不够，不能施展化功大法。\n");
  # 
  #     if ((int)target->query("neili") < 10 ||
  #             (int)target->query("max_neili") < 10)
  #         return notify_fail(target->name() +
  #                    "已然内力涣散，不必再化了。\n");
  # 
  #         if ((int)target->query("max_neili") > (int)me->query("max_neili") * 4 / 3 )
  #         return notify_fail( target->name() +
  #             "的内功修为远胜于你，你无法化他的内力！\n");
  # 
  #     message_combatd(HIR "$N" HIR "全身骨节爆响，双臂暴长数尺，手掌"
  #                 "刷的一抖，粘向$n！\n" NOR, me, target);
  # 
  #         if (target->query_skill("taixuan-gong", 1))
  #         {
  #                 message_sort(HIG "\n$N" HIG "刚将手掌接触到$n" HIG "肌肤，猛然觉得一股无比强大的"
  #                              "内劲反压回来，化功大法的内力却犹如石沉大海。$N" HIG "大吃一惊，连"
  #                              "忙将手缩回，再也不敢接近。\n" NOR);
  #                 return 1;
  # 
  #         }
  # 
  #         me->want_kill(target);
  # 
  #     if (living(target))
  #         if (! target->is_killing(me)) target->kill_ob(me);
  # 
  #         sp = me->query_skill("force") + me->query_skill("dodge");
  #         dp = target->query_skill("force") + target->query_skill("dodge");
  # 
  #         if ((sp / 2 + random(sp) > random(dp)) || ! living(target))
  #     {
  #         tell_object(target, HIR "你只觉天顶骨裂，全身功力"
  #                 "贯脑而出，如融雪般消失得无影无踪！\n" NOR);
  # 
  #                 target->add("max_neili", -1 * (random(4) + (me->query_skill("huagong-dafa", 1) - 90) / 8) );
  #                 if (target->query("max_neili") < 1)
  #             target->set("max_neili", 0);
  # 
  #                 me->start_busy(2 + random(2));
  #                 me->add("neili", -100);
  #                 if (! target->is_busy())target->start_busy(2);
  #     } else
  #     {
  #         message_combatd(HIY "可是$p" HIY "看破了$P"
  #                     HIY "的企图，内力猛地一震，借势溜"
  #                 "了开去。\n" NOR, me, target);
  #                 me->start_busy(2 + random(3));
  #                 me->add("neili", -100);
  #     }
  # 
  #     return 1;
  # }
end
