defmodule Kantele.Combat.Skills.Performs.QiantianZhi.Zhi do
  @moduledoc """
  perform「乾阳神指」（对照 `kungfu/skill/qiantian-zhi/zhi.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手（**`.c` 把这一步写了两遍，
  第 22~23 行与第 19~20 行完全相同，文案也相同**，故 E 侧分列两个同文案
  门槛）→ 乾天指法>=80 → 激发 finger 为乾天指法 → 准备 finger 为乾天指法 →
  内功>=100 → 真气>=100 → 目标存活。
  起手广播后由目标侧判定 `random(指法) > 目标招架/2`：命中则攻击方忙乱 2、
  `damage = 40 + 指法/3 + random(指法/3)`、外伤比例 30、扣 80 真气；
  未命中则攻击方忙乱 3、扣 50 真气。两种消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `.c` 的重复「只能对战斗中的对手使用」检查按**逐条字面一致**的判据在 E 侧
    保留两份（同 `pixie_jian/duo.ex` 对重复 mapped/prepared 门槛的处理）；
  - 命中判定用的 `me->query_skill("finger")` 与伤害基数同源，经 event data
    由攻击方传入；
  - `.c` 的 `damage = me->query_skill("finger")` 先整体赋值再改写为
    `40 + damage/3 + random(damage/3)`，E 侧按同一算式折算；
  - `.c` 起手与分支文案分两次发布（都累加进同一 `msg` 后一次
    `message_combatd`）；E 侧拆两处——起手在攻击方发布，分支文案在目标侧发布
    （判定需目标招架）；
  - 分支文案里的 `$p`/`$P` 分别指目标与攻击方
    （`$n/$p → :n2`、`$N/$P → :n1`）；
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

  @perform_id "qiantian-zhi/zhi"
  @move_name "「乾阳神指」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("finger")) ... damage = me->query_skill("finger")
    finger = Stats.skill(stats, "finger")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- target_recheck(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          finger: finger,
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

  # LPC: if (userp(me) && ! me->query("can_perform/qiantian-zhi/zhi"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #              return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  # .c 第 22~23 行把上一条检查原样又写了一遍（连文案都相同），按判据在 E 侧
  # 同样保留一份独立门槛（同 pixie_jian/duo.ex 处理重复门槛的做法）。
  defp target_recheck(combat) do
    case combat.enemies do
      [_enemy | _] -> :ok
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("qiantian-zhi", 1) < 80)
  #      if (me->query_skill_mapped("finger") != "qiantian-zhi")
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "qiantian-zhi") < 80 ->
        {:error, "你乾天指法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "finger") != "qiantian-zhi" ->
        {:error, "你没有激发乾天指法，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "qiantian-zhi")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "finger")

    if prepared != nil and hd(String.split(prepared, "/")) == "qiantian-zhi" do
      :ok
    else
      {:error, "你没有准备乾天指法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 100)
  #      if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你内功修为不够，难以施展#{@move_name}。\n"}

      character.meta.vitals.neili < 100 ->
        {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
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

  # LPC: msg = HIR "$N" HIR "陡然使出一招「乾阳神指」，双指齐施，同时朝$n"
  #            HIR "面门及胸口处点去。\n" NOR;
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      "$N陡然使出一招「乾阳神指」，双指齐施，同时朝$n面门及胸口处点去。\n",
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
    finger = Map.get(data, :finger, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("finger")) > target->query_skill("parry") / 2)
    parry = Stats.skill(character.meta.stats, "parry")

    if Engine.rand(rng, finger) > div(parry, 2) do
      # LPC: me->start_busy(2);
      #      damage = me->query_skill("finger");
      #      damage = 40 + damage / 3 + random(damage / 3);
      #      me->add("neili", -80);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                 HIR "结果$p" HIR "躲闪不及，登时被$P"
      #                                 HIR "一指点中，内息不由得一滞，难受之极。\n" NOR);
      damage = 40 + div(finger, 3) + Engine.rand(rng, div(finger, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(2);  me->add("neili", -80);
      Performs.feedback(attacker, 80, 2)

      conn
      |> Broadcast.publish(
        "结果$p躲闪不及，登时被$P一指点中，内息不由得一滞，难受之极。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3);  me->add("neili", -50);
      #      msg += CYN "可是$p" CYN "识破了$P"
      #             CYN "这一招，斜斜一跃避开。\n" NOR;
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish("可是$p识破了$P这一招，斜斜一跃避开。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHI "「" HIR "乾阳神指" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/qiantian-zhi/zhi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("qiantian-zhi", 1) < 80)
  #                 return notify_fail("你乾天指法不够娴熟，难以施展" ZHI "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "qiantian-zhi")
  #                 return notify_fail("你没有激发乾天指法，难以施展" ZHI "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "qiantian-zhi")
  #                 return notify_fail("你没有准备乾天指法，难以施展" ZHI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你内功修为不够，难以施展" ZHI "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不够，难以施展" ZHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "陡然使出一招「乾阳神指」，双指齐施，同时朝$n"
  #               HIR "面门及胸口处点去。\n" NOR;
  # 
  #         if (random(me->query_skill("finger")) > target->query_skill("parry") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("finger");
  #                 damage = 40 + damage / 3 + random(damage / 3);
  #                 me->add("neili", -80);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "结果$p" HIR "躲闪不及，登时被$P"
  #                                            HIR "一指点中，内息不由得一滞，难受之极。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -50);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
