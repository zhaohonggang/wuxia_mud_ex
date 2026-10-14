defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Wan do
  @moduledoc """
  perform「万蛊噬天」（对照 `kungfu/skill/qianzhu-wandushou/wan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 目标存活 →
  准备 hand 为千蛛万毒手 → 千蛛万毒手>=220 → 内功>=300 →
  内力上限>=3500 → 真气>=500 → 空手。
  起手广播后攻击方无条件扣 300 真气；目标 `apply/parry`、`apply/dodge`
  各减 `delta`（`delta = 千蛛万毒手/6`）、自身 `apply/unarmed_damage`
  加 `count`（五毒教为 `基本毒技/50*3`，其余门派为 0），持续 5 连击，
  连击结束即还原；收招忙乱 `1 + random(5)`。

  差异（TODO(migrate)）：
  - `.c` 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架管线）折算为一次
    五连击累加（同 `chongyang_shenzhang/lian.ex` 的裸 `do_attack` 折算）：
    每击命中判定 `千蛛万毒手/2 + random(千蛛万毒手)` 对 `闪避 - delta`，
    每击基础伤害 `千蛛万毒手/15 + count`，外伤按 1/3 计；
  - 目标的 `apply/parry`、`apply/dodge` 减 `delta` 与自身的
    `apply/unarmed_damage` 加 `count` 只覆盖连击期间（`.c` 在函数末尾即
    还原），E 侧分别折入命中判定与每击伤害，不落持久 buff；
  - 循环内 `random(3)==1 && !is_busy()` 的临时忙乱折算为单次判定
    （引擎 `Combat.start_busy/2` 取最大值，重复触发无叠加效果）；
  - `query_skill_prepared("hand")` 按引擎约定做绝招 ID 前缀比对
    （`Stats.prepared_perform/2` 返回的是绝招 ID，不是技能名）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "qianzhu-wandushou/wan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: skill = me->query_skill("qianzhu-wandushou", 1);
    #      poison = me->query_skill("poison");
    skill = Stats.skill(stats, "qianzhu-wandushou")
    poison = Stats.skill(stats, "poison")

    # LPC: delta = skill / 6;
    delta = div(skill, 6)

    # LPC: count = 0;
    #      if (me->query("family/family_name") == "五毒教")
    #              count = (int)(poison / 50) * 3;
    family = Family.name(Map.get(character.meta, :family, %{}))
    count = if family == "五毒教", do: div(poison, 50) * 3, else: 0

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_target_alive(target),
         :ok <- check_prepared(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          skill: skill,
          delta: delta,
          count: count,
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

  # LPC: if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/wan"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「万蛊噬天」只能对战斗中的对手使用。\n"}
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

  # LPC: if (me->query_skill_prepared("hand") != "qianzhu-wandushou")
  #              引擎的 Stats.prepared_perform/2 返回绝招 ID 或 nil，
  #              nil 与其它技能前缀都视为「没有准备」，单一分支即可。
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared != nil and hd(String.split(prepared, "/")) == "qianzhu-wandushou" do
      :ok
    else
      {:error, "你没有准备使用千蛛万毒手，无法施展万蛊噬天。\n"}
    end
  end

  # LPC: if (skill < 220)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "qianzhu-wandushou") < 220 do
      {:error, "你的千蛛万毒手修为有限，无法施展万蛊噬天。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 300)
  #      if (me->query("max_neili") < 3500)
  #      if (me->query("neili") < 500)
  defp check_resources(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够，难以施展万蛊噬天。\n"}

      vitals.max_neili < 3500 ->
        {:error, "你的内力修为没有达到那个境界，无法运转内力施展万蛊噬天。\n"}

      vitals.neili < 500 ->
        {:error, "你的真气不够，现在无法施展万蛊噬天。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须是空手才能施展万蛊噬天。\n"}
    else
      :ok
    end
  end

  # LPC: msg = RED "\n$N" RED "仰天一声长啸，强催内劲，全身"
  #              "竟浮现出隐隐碧绿之色。喝道：“万蛊噬天”,双"
  #              "掌猛\n然拍出，登时幻出漫天碧绿色掌影，毒气弥"
  #              "漫，笼罩$n" RED "全身！\n\n" NOR;
  #      message_combatd(msg, me, target);
  defp apply_effect(conn, character, target, rng) do
    # LPC: me->add("neili", -300);（无条件，位于连击之前）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 300, 0)}

    # LPC: me->start_busy(1 + random(5));（无条件，收招后置）
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 5))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "\n$N仰天一声长啸，强催内劲，全身竟浮现出隐隐碧绿之色。喝道：“万蛊噬天”,双掌猛\n然拍出，登时幻出漫天碧绿色掌影，毒气弥漫，笼罩$n全身！\n\n",
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
  def resolve_incoming(conn, character, _attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, data)
    end
  end

  defp do_resolve_incoming(conn, character, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = Map.get(data, :skill, 0)
    delta = Map.get(data, :delta, 0)
    count = Map.get(data, :count, 0)

    # LPC: if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
    #      连击 5 次各判定一次，折算为最多生效一次。
    combat =
      if Engine.rand(rng, 3) == 1 and not Combat.busy?(character.meta.combat) do
        Combat.start_busy(character.meta.combat, 1)
      else
        character.meta.combat
      end

    # LPC: for (i = 0; i < 5; i++) { ... COMBAT_D->do_attack(me, target, 0, 0); }
    #      折算：每击 level/2 + random(level) 对 (dodge - delta)，
    #      每击基础伤害 level/15 + count（unarmed_damage 加成折入）。
    dodge = max(Stats.skill(character.meta.stats, "dodge") - delta, 0)
    per_hit = max(div(skill, 15), 1) + count

    damage =
      Enum.reduce(1..5, 0, fn _, damage_acc ->
        if div(skill, 2) + Engine.rand(rng, skill) > dodge do
          damage_acc + per_hit + Engine.rand(rng, per_hit)
        else
          damage_acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
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
  #         int i, count, poison;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/wan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("「万蛊噬天」只能对战斗中的对手使用。\n");
  # 
  #         //晕倒后不可以再出pfm by over 20180129
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (me->query_skill_prepared("hand") != "qianzhu-wandushou")
  #                 return notify_fail("你没有准备使用千蛛万毒手，无法施展万蛊噬天。\n");
  # 
  #         skill = me->query_skill("qianzhu-wandushou", 1);
  #         poison = me->query_skill("poison");
  # 
  #         if (skill < 220)
  #                 return notify_fail("你的千蛛万毒手修为有限，无法施展万蛊噬天。\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功火候不够，难以施展万蛊噬天。\n");
  # 
  #         if (me->query("max_neili") < 3500)
  #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内力施展万蛊噬天。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，现在无法施展万蛊噬天。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展万蛊噬天。\n");
  # 
  #         msg = RED "\n$N" RED "仰天一声长啸，强催内劲，全身"
  #               "竟浮现出隐隐碧绿之色。喝道：“万蛊噬天”,双"
  #               "掌猛\n然拍出，登时幻出漫天碧绿色掌影，毒气弥"
  #               "漫，笼罩$n" RED "全身！\n\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  #         delta = skill / 6;
  #         count = 0;
  #         me->add("neili", -300);
  #         if (me->query("family/family_name") == "五毒教")
  #             count = (int)(poison / 50) * 3;
  #         target->add_temp("apply/parry", -delta);
  #         target->add_temp("apply/dodge", -delta);
  #         me->add_temp("apply/unarmed_damage", count);
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         target->add_temp("apply/parry", delta);
  #         target->add_temp("apply/dodge", delta);
  #         me->add_temp("apply/unarmed_damage", -count);
  #         me->start_busy(1 + random(5));
  # 
  #         return 1;
  # }
end
