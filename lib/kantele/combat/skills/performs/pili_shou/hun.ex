defmodule Kantele.Combat.Skills.Performs.PiliShou.Hun do
  @moduledoc """
  perform「天地混元」（对照 `kungfu/skill/pili-shou/hun.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 混元霹雳手>=140 →
  内功>=160 → 内力上限>=2400 → 真气>=340 → 准备 hand 为混元霹雳手 →
  目标存活。
  起手广播后由目标侧判定 `ap/2 + random(ap) > dp`（`ap = 手法 + 内功`、
  `dp = 目标内功 + 目标招架`）：命中则 `damage = ap + random(ap/2)`、
  攻击方扣 300 真气并忙乱 `1 + random(2)`，目标受
  `do_damage(UNARMED_ATTACK, damage, 70)`；否则攻击方扣 200 真气并忙乱 3，
  广播「躲过了必杀一击」文案。

  差异（TODO(migrate)）：
  - `ap` 在攻击方算好经事件 data 下发，`dp` 在目标侧计算（同
    `pangu_qishi/kai.ex`）；
  - 两条分支的 neili 消耗/忙乱为命中相关，故经
    `Performs.feedback(attacker, neili, busy)` 回授攻击方；
  - `COMBAT_D->do_damage(..., 70, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 70, 100))`；
  - `.c` 等级门槛文案写作「等级不够, 不能施展」（半角逗号 + 半角空格），
    与命中文案的弯引号 `“哇”` 均按原文逐字保留；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "pili-shou/hun"
  @move_name "「天地混元」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("hand") + me->query_skill("force");
    ap = Stats.skill(stats, "hand") + Stats.skill(stats, "force")

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

  # LPC: if (userp(me) && ! me->query("can_perform/pili-shou/hun"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! me->is_fighting(target))
  #      （.c 未单独判 ! target；敌人列表为空即视为不在战斗中）
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("pili-shou", 1) < 140)
  #      if (me->query_skill("force", 1) < 160)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "pili-shou") < 140 ->
        {:error, "你的混元霹雳手等级不够, 不能施展#{@move_name}！\n"}

      Stats.skill(stats, "force") < 160 ->
        {:error, "你内功修为不够，无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("max_neili") < 2400)
  #      if (me->query("neili") < 340)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2400 ->
        {:error, "你内力修为不足，无法施展#{@move_name}！\n"}

      vitals.neili < 340 ->
        {:error, "你的内力不够，无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "pili-shou")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared != nil and hd(String.split(prepared, "/")) == "pili-shou" do
      :ok
    else
      {:error, "你没有准备使用混元霹雳手，无法施展#{@move_name}！\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "怒喝一声，施出绝招「" HIW "天地混元" HIC "」，双掌交错"
    #            "袭向$n" HIC "，掌风凌厉，隐隐带有风雷之势。\n" NOR;
    #      之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
    conn =
      Broadcast.publish(
        conn,
        "$N怒喝一声，施出绝招「天地混元」，双掌交错袭向$n，掌风凌厉，隐隐带有风雷之势。\n",
        n1: character.name,
        n2: target.name
      )

    put_character(conn, character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
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

    # LPC: dp = target->query_skill("force") + target->query_skill("parry");
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { me->add("neili", -300);
    #        damage = ap + random(ap / 2);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
    #                    HIR "$n" HIR "只觉得胸前一阵剧痛，“哇”的一"
    #                    "声喷出一口鲜血！\n" NOR);
    #        me->start_busy(1 + random(2)); }
    #      else
    #      { me->add("neili", -200);
    #        msg += CYN "只见$n" CYN "不慌不忙，轻轻一闪，躲过"
    #                       "了$N" CYN "的必杀一击！\n" NOR;
    #        me->start_busy(3); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      Performs.feedback(attacker, 300, 1 + Engine.rand(rng, 2))
      damage = ap + Engine.rand(rng, div(ap, 2))
      vitals = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 70, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn
      |> Broadcast.publish(
        "$n只觉得胸前一阵剧痛，“哇”的一声喷出一口鲜血！\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 200, 3)

      Broadcast.publish(
        conn,
        "只见$n不慌不忙，轻轻一闪，躲过了$N的必杀一击！\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 天地混元
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WU "「" HIW "天地混元" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     // object weapon;
  #     int skill, ap, dp, damage;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/pili-shou/hun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! me->is_fighting(target))
  #         return notify_fail(WU "只能对战斗中的对手使用。\n");
  # 
  #     skill = me->query_skill("pili-shou", 1);
  # 
  #     if (skill < 140)
  #         return notify_fail("你的混元霹雳手等级不够, 不能施展" WU "！\n");
  # 
  #     if (me->query_skill("force", 1) < 160)
  #         return notify_fail("你内功修为不够，无法施展" WU "！\n");
  # 
  #     if (me->query("max_neili") < 2400)
  #         return notify_fail("你内力修为不足，无法施展" WU "！\n");
  # 
  #     if (me->query("neili") < 340)
  #         return notify_fail("你的内力不够，无法施展" WU "！\n");
  # 
  #         if (me->query_skill_prepared("hand") != "pili-shou")
  #                 return notify_fail("你没有准备使用混元霹雳手，无法施展" WU "！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "怒喝一声，施出绝招「" HIW "天地混元" HIC "」，双掌交错"
  #               "袭向$n" HIC "，掌风凌厉，隐隐带有风雷之势。\n" NOR;
  # 
  #     ap = me->query_skill("hand") + me->query_skill("force");
  #     dp = target->query_skill("force") + target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->add("neili", -300);
  #         damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "只觉得胸前一阵剧痛，“哇”的一"
  #                                            "声喷出一口鲜血！\n" NOR);
  #         me->start_busy(1 + random(2));
  #     } else
  #     {
  #         me->add("neili", -200);
  #         msg += CYN "只见$n" CYN "不慌不忙，轻轻一闪，躲过"
  #                        "了$N" CYN "的必杀一击！\n" NOR;
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
