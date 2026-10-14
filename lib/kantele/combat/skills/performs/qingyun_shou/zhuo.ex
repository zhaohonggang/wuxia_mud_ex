defmodule Kantele.Combat.Skills.Performs.QingyunShou.Zhuo do
  @moduledoc """
  perform「捕风捉影」（对照 `kungfu/skill/qingyun-shou/zhuo.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 青云手>=50 → 内功>=100 →
  真气>=100 → 激发 hand 为青云手 → 准备 hand 为青云手 → 目标存活。
  起手广播后由目标侧判定 `random(基本手法)` 对 `目标闪避/2`：
  命中则攻击方忙乱 2、`damage = 手法/3 + random(手法/3)`、外伤 35、
  扣 50 真气；未命中则攻击方忙乱 3、扣 30 真气。两种消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `ZHUO` 宏展开后的 `「捕风捉影」` 已并入门槛字面量，E 侧直接写全串；
  - `query_skill_prepared("hand")` 按引擎约定做绝招 ID 前缀比对
    （`Stats.prepared_perform/2` 返回的是绝招 ID，不是技能名）；
  - 命中判定用的 `me->query_skill("hand")` 与伤害基数同源，经 event data
    由攻击方传入；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Vitals
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "qingyun-shou/zhuo"
  @move_name "「捕风捉影」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: damage = me->query_skill("hand");
    #      if (random(damage) > target->query_skill("dodge") / 2)
    hand = Stats.skill(stats, "hand")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          hand: hand,
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

  # LPC: if (userp(me) && ! me->query("can_perform/qingyun-shou/zhuo"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("qingyun-shou", 1) < 50)
  #      if ((int)me->query_skill("force") < 100)
  #      if ((int)me->query("neili") < 100)
  #      if (me->query_skill_mapped("hand") != "qingyun-shou")
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "qingyun-shou") < 50 ->
        {:error, "你的青云手不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      character.meta.vitals.neili < 100 ->
        {:error, "你现在真气不够，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "hand") != "qingyun-shou" ->
        {:error, "你没有激发青云手，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "qingyun-shou")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared != nil and hd(String.split(prepared, "/")) == "qingyun-shou" do
      :ok
    else
      {:error, "你现在没有准备使用青云手，难以施展#{@move_name}。\n"}
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

  # LPC: msg = WHT "$N" WHT "划身错步，单手拂过，手影虚虚实实，难辨真伪，完"
  #              "全笼罩$n" WHT "。\n" NOR;
  #      …命中/失手在目标侧结算（dp 需目标闪避）…
  defp apply_effect(conn, character, target) do
    conn
    |> Broadcast.publish(
      "$N划身错步，单手拂过，手影虚虚实实，难辨真伪，完全笼罩$n。\n",
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
    hand = Map.get(data, :hand, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("hand")) > target->query_skill("dodge") / 2)
    if Engine.rand(rng, hand) > div(Stats.skill(character.meta.stats, "dodge"), 2) do
      # LPC: me->start_busy(2);
      #      damage = me->query_skill("hand");
      #      damage = damage / 3 + random(damage / 3);
      #      me->add("neili", -50);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35, HIR "…");
      damage = div(hand, 3) + Engine.rand(rng, div(hand, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 35, 100))

      Performs.feedback(attacker, 50, 2)

      conn
      |> Broadcast.publish(
        "$p一时辨别不清虚实，被$P手影划过气门，气血翻滚，几乎窒息。\n",
        bindings
      )
      |> put_character(%{character | meta: %{character.meta | vitals: vitals}})
    else
      # LPC: me->start_busy(3); me->add("neili", -30);
      #      msg += CYN "可是$p" CYN "识破了$P" CYN "这一招，斜斜一跃避开。\n" NOR;
      Performs.feedback(attacker, 30, 3)

      conn
      |> Broadcast.publish("可是$p识破了$P这一招，斜斜一跃避开。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUO "「" WHT "捕风捉影" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/qingyun-shou/zhuo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUO "只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("qingyun-shou", 1) < 50)
  #                 return notify_fail("你的青云手不够娴熟，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，难以施展" ZHUO "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" ZHUO "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "qingyun-shou")
  #                 return notify_fail("你没有激发青云手，难以施展" ZHUO "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "qingyun-shou")
  #                 return notify_fail("你现在没有准备使用青云手，难以施展" ZHUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "划身错步，单手拂过，手影虚虚实实，难辨真伪，完"
  #               "全笼罩$n" WHT "。\n" NOR;
  # 
  #         if (random(me->query_skill("hand")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("hand");
  #                 damage = damage / 3 + random(damage / 3);
  #                 me->add("neili", -50);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                            HIR "$p" HIR "一时辨别不清虚实，被$P"
  #                                            HIR "手影划过气门，气血翻滚，几乎窒息。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -30);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
