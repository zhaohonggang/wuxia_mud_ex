defmodule Kantele.Combat.Skills.Performs.PoyuQuan.Po do
  @moduledoc """
  perform「破石一击」（对照 `kungfu/skill/poyu-quan/po.c`）

  门槛（按 .c 顺序）：战斗中的对手 → 已学此招 → 劈石破玉拳>=140 →
  内功>=120 → 真气>=300 → 准备 cuff 为劈石破玉拳 → 目标存活。
  起手广播后由目标侧单次判定
  `ap/2 + random(ap) > dp`（`ap = 拳法 + 膂力*10`、`dp = 目标内功 + 目标膂力*10`）：
  命中则 `damage = ap/2 + random(ap/2)`、外伤比例 80、攻击方扣 220 真气并
  忙乱 2；未命中则攻击方扣 120 真气并忙乱 3。两种消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `.c` 起手与分支文案分两次发布（都累加进同一 `msg` 后一次
    `message_combatd`）；E 侧同样拆两处——起手在攻击方发布，分支文案在
    目标侧发布（`dp` 需目标膂力/内功）；
  - `.c` 未命中文案里的 `$p`/`$P` 分别指目标与攻击方
    （`$n/$p → :n2`、`$N/$P → :n1`）；
  - `me->query_str()` 经 `Stats.query_str/1` 取（框架同样含技能加成项）；
  - `.c` 门槛文案 `"你的内功修为还不够，无法施展" PO "\n"` 在绝招名后无句号
    （原文如此，逐字保留）；
  - `.c` 选目标时先 `clean_up_enemy()` 再 `select_opponent()`；框架侧由
    `combat.enemies` 直接提供当前对手，无对应清理动作（信息性差异）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "poyu-quan/po"
  @move_name "「破石一击」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("cuff") + me->query_str() * 10;
    ap = Stats.skill(stats, "cuff") + Stats.query_str(stats) * 10

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

  # LPC: if (userp(me) && ! me->query("can_perform/poyu-quan/po"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("poyu-quan", 1) < 140)
  #      if ((int)me->query_skill("force", 1) < 120)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "poyu-quan") < 140 ->
        {:error, "你的劈石破玉拳不够娴熟，无法施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功修为还不够，无法施展#{@move_name}\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "poyu-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "poyu-quan" do
      :ok
    else
      {:error, "你没有准备使用劈石破玉拳，无法施展#{@move_name}。\n"}
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

  # LPC: msg = HIY "$N" HIY "大喝一声，拳头如闪电一般重重的击向$n" HIY "。\n"NOR;
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      "$N大喝一声，拳头如闪电一般重重的击向$n。\n",
      n1: character.name,
      n2: target.name
    )
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_str() * 10;
    dp = Stats.skill(character.meta.stats, "force") + Stats.query_str(character.meta.stats) * 10

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap / 2 + random(ap / 2);
    #        me->add("neili", -220);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
    #                                   HIR "只见$P" HIR "这一拳把$p" HIR
    #                                           "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
    #        me->start_busy(2); }
    #      else
    #      { msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
    #                     HIC "这一招。\n"NOR;
    #        me->add("neili", -120);
    #        me->start_busy(3); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -220);  me->start_busy(2);
      Performs.feedback(attacker, 220, 2)

      conn
      |> Broadcast.publish(
        "只见$P这一拳把$p飞了出去，重重的摔在地上，吐血不止！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -120);  me->start_busy(3);
      Performs.feedback(attacker, 120, 3)

      conn
      |> Broadcast.publish("可是$p奋力招架，硬生生的挡开了$P这一招。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // poshi.c 破石一击
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" HIW "破石一击" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/poyu-quan/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("poyu-quan", 1) < 140)
  #         return notify_fail("你的劈石破玉拳不够娴熟，无法施展" PO "。\n");
  # 
  #     if ((int)me->query_skill("force", 1) < 120)
  #         return notify_fail("你的内功修为还不够，无法施展" PO "\n");
  # 
  #     if ((int)me->query("neili") < 300)
  #         return notify_fail("你现在真气不够，无法施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "poyu-quan")
  #                 return notify_fail("你没有准备使用劈石破玉拳，无法施展" PO "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "大喝一声，拳头如闪电一般重重的击向$n" HIY "。\n"NOR;
  # 
  #         ap = me->query_skill("cuff") + me->query_str() * 10;
  #         dp = target->query_skill("force") + target->query_str() * 10;
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap / 2 + random(ap / 2);
  # 
  #                 me->add("neili", -220);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                    HIR "只见$P" HIR "这一拳把$p" HIR
  #                                            "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                        HIC "这一招。\n"NOR;
  #         me->add("neili", -120);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
