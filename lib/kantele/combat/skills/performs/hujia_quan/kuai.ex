defmodule Kantele.Combat.Skills.Performs.HujiaQuan.Kuai do
  @moduledoc """
  perform「奔拳快打」（source hujia-quan/kuai.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手（weapon/secondary_weapon）→
  目标非忙 → 基本内功>=100 → 胡家拳法>=80 → 激发 cuff 为胡家拳法 →
  准备 cuff 为胡家拳法 → 真气>=80 → 目标存活。
  攻击方恒扣 40 真气；命中判定 `random(战斗经验)` vs 目标 `战斗经验/3`：
  命中则广播「手忙脚乱」并令目标忙乱 `cuff/25 + 2`；
  未命中则广播「避开拳影」并令攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` / `target->query("combat_exp")` 取引用快照
    （`%{id,pid,name,room_id}`）的 meta，缺 meta 时分别按「非忙」「经验 0」处理；
  - 攻击方忙乱只在失手分支，经 `Performs.feedback/3` 由目标侧回传。
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

  @perform_id "hujia-quan/kuai"
  @move_name "「奔拳快打」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hujia-quan")
    exp = Map.get(stats, :combat_exp, 0)
    cuff = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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
          exp: exp,
          cuff: cuff,
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

  # LPC: if (userp(me) && ! me->query("can_perform/hujia-quan/kuai"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy()) return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp target_busy?(target) do
    case get_in(target, [:meta, :combat, :busy]) do
      busy when is_integer(busy) -> busy > 0
      _ -> false
    end
  end

  # LPC: if (query_skill("force") < 100) / if (query_skill("hujia-quan", 1) < 80)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "hujia-quan") < 80 ->
        {:error, "你的胡家拳法不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("cuff") != "hujia-quan")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "cuff") == "hujia-quan" do
      :ok
    else
      {:error, "你没有激发胡家拳法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "hujia-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared == nil or prepared |> String.split("/") |> hd() != "hujia-quan" do
      {:error, "你没有准备胡家拳法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 80)
  defp check_resources(character) do
    if character.meta.vitals.neili < 80 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = WHT "$N" WHT "纵步上前，拳招迭出，疾如奔雷，霎时已向$n" WHT "攻出数拳。\n" NOR;
    #      me->add("neili", -40);
    #      命中/失手与忙乱均在目标侧结算（dp 需目标战斗经验）。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 40}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish("$N纵步上前，拳招迭出，疾如奔雷，霎时已向$n攻出数拳。\n",
      n1: character.name,
      n2: target.name
    )
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
    exp = max(Map.get(data, :exp, 0), 1)
    cuff = Map.get(data, :cuff, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
    dp = div(Map.get(stats, :combat_exp, 0), 3)

    if Engine.rand(rng, exp) > dp do
      # LPC: msg += HIR "结果$n" HIR "无法分清$N" HIR "招式中的虚实，" "不由手忙脚乱。\n" NOR;
      #      target->start_busy((int)me->query_skill("cuff") / 25 + 2);
      combat = Combat.start_busy(character.meta.combat, div(cuff, 25) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$n无法分清$N招式中的虚实，不由手忙脚乱。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的虚招，轻轻一闪，" "避开了这骤雨般的拳影。\n" NOR;
      #      me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$P的虚招，轻轻一闪，避开了这骤雨般的拳影。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KUAI "「" WHT "奔拳快打" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/hujia-quan/kuai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(KUAI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(KUAI "只能空手施展。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #     if ((int)me->query_skill("force") < 100)
  #         return notify_fail("你的内功火候不足，难以施展" KUAI "。\n");
  # 
  #     if ((int)me->query_skill("hujia-quan", 1) < 80)
  #         return notify_fail("你的胡家拳法不够娴熟，难以施展" KUAI "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "hujia-quan")
  #                 return notify_fail("你没有激发胡家拳法，难以施展" KUAI "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "hujia-quan")
  #                 return notify_fail("你没有准备胡家拳法，难以施展" KUAI "。\n");
  # 
  #         if (me->query("neili") < 80)
  #                 return notify_fail("你现在真气不够，难以施展" KUAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = WHT "$N" WHT "纵步上前，拳招迭出，疾如奔雷，霎时已向$n" WHT "攻出数拳。\n" NOR;
  # 
  #         me->add("neili", -40);
  #     if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
  #         {
  #         msg += HIR "结果$n" HIR "无法分清$N" HIR "招式中的虚实，"
  #                        "不由手忙脚乱。\n" NOR;
  #         target->start_busy((int)me->query_skill("cuff") / 25 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的虚招，轻轻一闪，"
  #                        "避开了这骤雨般的拳影。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
