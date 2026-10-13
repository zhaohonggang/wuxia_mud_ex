defmodule Kantele.Combat.Skills.Performs.HunyuanZhang.Wuji do
  @moduledoc """
  perform「混元无极」（source hunyuan-zhang/wuji.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 混元掌>=120 →
  基本内功>=120 → 内力上限>=1400 → 真气>=240 → 准备 strike 为混元掌 →
  目标存活。
  命中判定 `ap/2 + random(ap)` vs 目标 `force`（`ap = 基本掌法`）：
  命中则伤害 `ap + random(ap/2)`（qi 伤 + 80% 外伤）、扣 220 真气、
  忙乱 `1+random(2)`；未命中则扣 120 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传；
  - `.c` 用 `message_combatd(msg, me, target)` 把起手式与结算文案合成一条广播，
    此处按本仓库约定拆为「攻击方发起手式 / 目标侧发结算文案」两条。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "hunyuan-zhang/wuji"
  @move_name "「混元无极」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hunyuan-zhang")
    # LPC: ap = me->query_skill("strike");
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/hunyuan-zhang/wuji"))
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

  # LPC: if (skill < 120) / if (me->query_skill("force", 1) < 120)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "hunyuan-zhang") < 120 ->
        {:error, "你的混元掌等级不够, 不能施展#{@move_name}！\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你内功修为不够，无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("max_neili") < 1400) / if (me->query("neili") < 240)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1400 -> {:error, "你内力修为不足，无法施展#{@move_name}！\n"}
      vitals.neili < 240 -> {:error, "你的内力不够，无法施展#{@move_name}！\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "hunyuan-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or prepared |> String.split("/") |> hd() != "hunyuan-zhang" do
      {:error, "你没有准备使用混元掌，无法施展#{@move_name}！\n"}
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
    # LPC: msg = HIC "$N" HIC "怒喝一声，潜运「" HIW "混元无极" HIC "」，双拳挟"
    #            "着隐隐的风雷之声向$n" HIC "击去。\n" NOR;
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 force）。
    conn
    |> Broadcast.publish(
      "$N怒喝一声，潜运#{@move_name}，双拳挟着隐隐的风雷之声向$n击去。\n",
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
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
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

    # LPC: dp = target->query_skill("force");
    dp = Stats.skill(stats, "force")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                HIR "$n" HIR "只觉得胸前一阵剧痛，“哇”的一声喷出一口鲜血！\n" NOR);
      #      me->add("neili", -220); me->start_busy(1 + random(2));
      damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 220, 1 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只觉得胸前一阵剧痛，“哇”的一声喷出一口鲜血！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "只见$n" CYN "不慌不忙，轻轻一闪，躲过了$N" CYN "的必杀一击！\n" NOR;
      #      me->add("neili", -120); me->start_busy(3);
      Performs.feedback(attacker, 120, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("只见$n不慌不忙，轻轻一闪，躲过了$N的必杀一击！\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wuji.c 混元无极
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WU "「" HIW "混元无极" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  # //    object weapon;
  #     int skill, ap, dp, damage;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/hunyuan-zhang/wuji"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! me->is_fighting(target))
  #         return notify_fail(WU "只能对战斗中的对手使用。\n");
  # 
  #     skill = me->query_skill("hunyuan-zhang", 1);
  # 
  #     if (skill < 120)
  #         return notify_fail("你的混元掌等级不够, 不能施展" WU "！\n");
  # 
  #     if (me->query_skill("force", 1) < 120)
  #         return notify_fail("你内功修为不够，无法施展" WU "！\n");
  # 
  #     if (me->query("max_neili") < 1400)
  #         return notify_fail("你内力修为不足，无法施展" WU "！\n");
  # 
  #     if (me->query("neili") < 240)
  #         return notify_fail("你的内力不够，无法施展" WU "！\n");
  # 
  #         if (me->query_skill_prepared("strike") != "hunyuan-zhang")
  #                 return notify_fail("你没有准备使用混元掌，无法施展" WU "！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "怒喝一声，潜运「" HIW "混元无极" HIC "」，双拳挟"
  #               "着隐隐的风雷之声向$n" HIC "击去。\n" NOR;
  # 
  #     ap = me->query_skill("strike");
  #     dp = target->query_skill("force");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->add("neili", -220);
  #         damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "只觉得胸前一阵剧痛，“哇”的一"
  #                                            "声喷出一口鲜血！\n" NOR);
  #         me->start_busy(1 + random(2));
  #     } else
  #     {
  #         me->add("neili", -120);
  #         msg += CYN "只见$n" CYN "不慌不忙，轻轻一闪，躲过"
  #                        "了$N" CYN "的必杀一击！\n" NOR;
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
