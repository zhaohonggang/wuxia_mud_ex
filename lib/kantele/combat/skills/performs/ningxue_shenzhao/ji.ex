defmodule Kantele.Combat.Skills.Performs.NingxueShenzhao.Ji do
  @moduledoc """
  perform「疾电」（对照 `kungfu/skill/ningxue-shenzhao/ji.c`）

  门槛（按 .c 顺序）：已学此招（`.c` 的 `userp(me) && !can_perform`，文案沿用
  `.c` 原句）→ 战斗中的对手 → 已准备 claw 为凝血神爪 → 凝血神爪>=250 →
  内功>=350 → 内力上限>=5000 → 真气>=500 → 空手 → 目标存活。
  起手广播后攻击方扣 300 真气，随后连出 7 击（每击 1/3 概率令未忙乱的目标
  忙乱 1 回合），收招忙乱 `1 + random(5)`。

  差异（TODO(migrate)）：
  - LPC 的 `delta` 声明后从未赋值（恒 0），故 `add_temp("apply/parry", ±delta)`
    与 `add_temp("apply/dodge", ±delta)` 均为空操作，E 侧不折算（信息保留在
    本注释与文末源码块中）；
  - `.c` 无 ap/dp 判定，连击折算同 `luoyan_jian/luo.ex`：每击
    `ap/2 + random(ap)` vs 目标 dodge，`per_hit = max(ap/15,1)`，累加后
    `damage(:qi,d) |> wound(:qi, div(d,3))`；`do_attack` 无独立命中/失手文案，
    由引擎动作表生成，故本文件不再自行发布逐击结果文案；
  - `me->start_busy(1 + random(5))` 在 `.c` 中位于 7 击之后，而 E 侧起手效果
    （apply_effect）与目标侧连击是两个异步事件，故收敛在攻击方 apply_effect 中
    统一结算；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底（同 `chongyang_shenzhang/lian.ex`）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "ningxue-shenzhao/ji"
  @move_name "「疾电」"

  # LPC: for (i = 0; i < 7; i++) COMBAT_D->do_attack(me, target, 0, 0);
  @strikes 7

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "ningxue-shenzhao")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_prepared(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(combat),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/ningxue-shenzhao/ji"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你还不会使用这一招！\n"}
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

  # LPC: if (me->query_skill_prepared("claw") != "ningxue-shenzhao")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "claw")

    if prepared == nil or hd(String.split(prepared, "/")) != "ningxue-shenzhao" do
      {:error, "你没有准备使用凝血神爪，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("ningxue-shenzhao", 1) < 250)
  #      if (me->query_skill("force", 1) < 350)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "ningxue-shenzhao") < 250 ->
        {:error, "你的凝血神爪修为有限，无法使用#{@move_name}！\n"}

      Stats.skill(stats, "force") < 350 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("max_neili") < 5000)
  #      if (me->query("neili") < 500)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 ->
        {:error, "你的内力修为没有达到那个境界，无法运转内力形成#{@move_name}！\n"}

      vitals.neili < 500 ->
        {:error, "你的真气不够，现在无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你必须是空手才能施展#{@move_name}！\n"}
    else
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

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIR "$N" HIR "仰天一声长啸，飞身跃起，双爪幻出漫天爪影，气势恢弘，"
    #            HIR "宛如疾电一般笼罩$n" HIR "各处要穴！\n" NOR;
    #      message_combatd(msg, me, target);
    #      me->add("neili", -300);
    #      target->add_temp("apply/parry", delta);   // delta 从未赋值，恒 0，空操作
    #      target->add_temp("apply/dodge", delta);   // 同上
    #      … 7 击（目标侧结算）…
    #      target->add_temp("apply/parry", -delta);  // 空操作
    #      target->add_temp("apply/dodge", -delta);  // 空操作
    #      me->start_busy(1 + random(5));
    conn =
      Broadcast.publish(
        conn,
        "$N仰天一声长啸，飞身跃起，双爪幻出漫天爪影，气势恢弘，宛如疾电一般笼罩$n各处要穴！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -300);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 300, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(1 + random(5));
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 5))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: for (i = 0; i < 7; i++) { if (! me->is_fighting(target)) break;
    #            if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
    #            COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 ap/15 基础伤害 + 命中判定（ap/2 + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc =
          if Engine.rand(rng, 3) == 1 and not Combat.busy?(combat_acc) do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(ap, 15), 1)
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // ji.c 疾电
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // mapping prepare;
  #         string msg;
  #         int skill;
  #         int delta;
  #         int i;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/ningxue-shenzhao/ji"))
  #                 return notify_fail("你还不会使用这一招！\n");
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("「疾电」只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "ningxue-shenzhao")
  #                 return notify_fail("你没有准备使用凝血神爪，无法施展「疾电」。\n");
  # 
  #         skill = me->query_skill("ningxue-shenzhao", 1);
  # 
  #         if (skill < 250)
  #                 return notify_fail("你的凝血神爪修为有限，无法使用「疾电」！\n");
  # 
  #         if (me->query_skill("force") < 350)
  #                 return notify_fail("你的内功火候不够，难以施展「疾电」！\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内力形成「疾电」！\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，现在无法施展「疾电」！\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展「疾电」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "仰天一声长啸，飞身跃起，双爪幻出漫天爪影，气势恢弘，宛如疾电一般笼罩$n" HIR "各处要穴！\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -300);
  #         target->add_temp("apply/parry", delta);
  #         target->add_temp("apply/dodge", delta);
  #         for (i = 0; i < 7; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         target->add_temp("apply/parry", -delta);
  #         target->add_temp("apply/dodge", -delta);
  #         me->start_busy(1 + random(5));
  # 
  #         return 1;
  # }
end
