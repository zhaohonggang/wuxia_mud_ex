defmodule Kantele.Combat.Skills.Performs.HuanyinZhi.Huanyin do
  @moduledoc """
  perform「幻阴神指」（source huanyin-zhi/huanyin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：房间非 no_fight → 目标为对手（且为 character）→
  目标非 `not_living` → 基本内功>=300 → 幻阴指法>=150 → 激发 finger 为幻阴指法 →
  真气>=400 → 目标存活。
  `lvl = 基本指法/2 + 幻阴指法`；命中判定 `lvl/2 + random(lvl)` vs 目标 `force`：
  命中则伤害 `lvl + random(lvl/2)`（qi 伤 + 40% 外伤）、
  附加 huanyin_poison（`level = lvl/2 + random(lvl/2)`，
  `duration = lvl/40 + random(lvl/18)`）、扣 320 真气、忙乱 2；
  未命中则扣 80 真气、忙乱 4。

  差异（TODO(migrate)）：
  - 房间 `no_fight` 经 `character.meta.room` 读取（同 `hamagong/tan.ex`）；
  - `target->query("not_living")` 取引用快照的 meta（缺 meta 时按存活处理）；
  - `target->affect_by("huanyin_poison", …)` 折算为 `ConditionEvent.apply_poison/2`
    （`.c` 未给毒名，此处补 `"name" => "幻阴寒毒"`，取自
    `kungfu/condition/huanyin_poison.c` 的 `chinese_name()`，仅供显示）；
  - `me->want_kill(target)` / `target->kill_ob(me)` 的敌对标记未在引擎侧建模。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "huanyin-zhi/huanyin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    # LPC: lvl = query_skill("finger", 1) / 2 + query_skill("huanyin-zhi", 1);
    lvl = div(Stats.skill(stats, "finger"), 2) + Stats.skill(stats, "huanyin-zhi")

    with :ok <- check_perform_known(character),
         :ok <- check_no_fight(character),
         {:ok, target} <- target(combat),
         :ok <- check_not_living(target),
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

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("这里不能攻击别人! \n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "这里不能攻击别人! \n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if (! target || ! target->is_character()) return notify_fail("幻阴神指只能对对手使用。\n");
  # 敌人列表只含 character，故 is_character 隐含成立。
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "幻阴神指只能对对手使用。\n"}
    end
  end

  # LPC: if (target->query("not_living")) return notify_fail("看清楚，那不是活人。\n");
  defp check_not_living(target) do
    if Map.get(target_meta(target), :not_living) do
      {:error, "看清楚，那不是活人。\n"}
    else
      :ok
    end
  end

  # LPC: if (query_skill("force") < 300) / if (query_skill("huanyin-zhi", 1) < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不足以施展幻阴神指。\n"}

      Stats.skill(stats, "huanyin-zhi") < 150 ->
        {:error, "你的幻阴指法修为不够，现在还无法施展幻阴神指。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("finger") != "huanyin-zhi")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "finger") == "huanyin-zhi" do
      :ok
    else
      {:error, "你没有激发幻阴指法，无法施展幻阴神指。\n"}
    end
  end

  # LPC: if (me->query("neili") < 400) return notify_fail("你的真气不够，现在无法施展幻阴神指。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，现在无法施展幻阴神指。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp target_meta(target), do: Map.get(target, :meta) || %{}

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIG "$N" HIG "深深的吸了一口气，缓缓的刺出一指，挟带一股寒气逼向$n" HIG "。\n" NOR;
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 force）。
    conn
    |> Broadcast.publish("$N深深的吸了一口气，缓缓的刺出一指，挟带一股寒气逼向$n。\n",
      n1: character.name,
      n2: target.name
    )
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
    lvl = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (lvl / 2 + random(lvl) > target->query_skill("force"))
    dp = Stats.skill(stats, "force")

    if div(lvl, 2) + Engine.rand(rng, lvl) > dp do
      # LPC: target->affect_by("huanyin_poison",
      #          ([ "level" : lvl / 2 + random(lvl / 2),
      #             "id"    : me->query("id"),
      #             "duration" : lvl / 40 + random(lvl / 18) ]));
      poison_level = div(lvl, 2) + Engine.rand(rng, max(div(lvl, 2), 1))
      poison_duration = div(lvl, 40) + Engine.rand(rng, max(div(lvl, 18), 1))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "幻阴寒毒"
        })

      # LPC: damage = lvl + random(lvl / 2);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 40, HIG "$p" HIG "急忙后退，…");
      #      me->add("neili", -320); me->start_busy(2);
      damage = lvl + Engine.rand(rng, max(div(lvl, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 320, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$p急忙后退，然而这指何等玄妙，正好点中$p胸前，$p不禁打了一个冷战。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "运足内力，以深厚的内功化解了这一指的阴寒内力。\n" NOR;
      #      me->start_busy(4); me->add("neili", -80);
      Performs.feedback(attacker, 80, 4)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p运足内力，以深厚的内功化解了这一指的阴寒内力。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // huanyin.c 幻阴神指
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int lvl;
  #         int damage;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("这里不能攻击别人! \n");
  # 
  #     if (! target || ! target->is_character())
  #         return notify_fail("幻阴神指只能对对手使用。\n");
  # 
  #     if (target->query("not_living"))
  #         return notify_fail("看清楚，那不是活人。\n");
  # 
  #     if ((int)me->query_skill("force") < 300)
  #         return notify_fail("你的内功火候不足以施展幻阴神指。\n");
  # 
  #     if ((int)me->query_skill("huanyin-zhi", 1) < 150)
  #         return notify_fail("你的幻阴指法修为不够，现在还无法施展幻阴神指。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "huanyin-zhi")
  #                 return notify_fail("你没有激发幻阴指法，无法施展幻阴神指。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，现在无法施展幻阴神指。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIG "$N" HIG "深深的吸了一口气，缓缓的刺"
  #               "出一指，挟带一股寒气逼向$n" HIG "。\n" NOR;
  # 
  #         lvl = (int)me->query_skill("finger", 1) / 2 +
  #               (int)me->query_skill("huanyin-zhi", 1);
  #     if (lvl / 2 + random(lvl) > target->query_skill("force"))
  #         {
  #                 damage = lvl + random(lvl / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIG "$p" HIG "急忙后退，然而这指何等玄妙，正"
  #                                            "好点中$p" HIG "胸前，$p" HIG "不禁打了一个冷"
  #                                            "战。\n" NOR);
  #                 target->affect_by("huanyin_poison",
  #                                   ([ "level" : lvl / 2 + random(lvl / 2),
  #                                      "id"    : me->query("id"),
  #                                      "duration" : lvl / 40 + random(lvl / 18) ]));
  #                 me->add("neili", -320);
  #             me->start_busy(2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "运足内力，以深厚的内功"
  #                        "化解了这一指的阴寒内力。\n" NOR;
  #         me->start_busy(4);
  #                 me->add("neili", -80);
  #     }
  #     message_combatd(msg, me, target);
  #         me->want_kill(target);
  #         if (! target->is_killing(me)) target->kill_ob(me);
  #     return 1;
  # }
end
