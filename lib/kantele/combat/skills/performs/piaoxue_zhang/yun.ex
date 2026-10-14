defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Yun do
  @moduledoc """
  perform「云海明灯」（对照 `kungfu/skill/piaoxue-zhang/yun.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → **双手皆空**
  （`weapon` 与 `secondary_weapon` 均无）→ 内功>=200 → 飘雪穿云掌>=150 →
  真气>=200 且内力上限>=2000 → 激发 strike 为飘雪穿云掌 → 准备 strike 为
  飘雪穿云掌 → 目标存活。
  起手广播后攻击方扣 100 真气，连出 3 招（依次叠 `apply/attack` 30/90/180），
  收招忙乱 `2 + random(3)`。

  差异（TODO(migrate)）：
  - `.c` 逐招累加 `me->add_temp("apply/attack", ±30/±60/±90)` 的临时加成折入
    目标侧逐击命中判定（累计 +30/+90/+180；攻击方本地 temp 对远程结算无意义），
    收招的 `-180` 不再重复落账（同 `luoyan_jian/luo.ex`）；
  - `.c` 的 3 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15` 基础伤害 + 命中判定（`ap/2 + 累计加成 + random(ap)` vs 目标 dodge）；
    `do_attack` 无独立命中/失手文案，由引擎动作表生成，故本文件不再自行发布
    逐击结果文案；
  - `.c` 起手文案用 `message_combatd(msg, me)`（未传 target），此处按引擎惯例
    仍作房间广播；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "piaoxue-zhang/yun"
  @move_name "「云海明灯」"

  # LPC: 第一招 apply/attack +30 / 第二招 +90 / 第三招 +180（逐招累加）。
  @attack_bonus [30, 90, 180]

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: 逐击命中判定用 strike 等级作基数。
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          bonuses: @attack_bonus,
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

  # LPC: if (userp(me) && ! me->query("can_perform/piaoxue-zhang/yun"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "你必须空手才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  #      if (me->query_skill("piaoxue-zhang", 1) < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功的修为不够，无法施展#{@move_name}。\n"}

      Stats.skill(stats, "piaoxue-zhang") < 150 ->
        {:error, "你的飘雪穿云掌修为不够，无法施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 200 || me->query("max_neili") < 2000)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 200 or vitals.max_neili < 2000 do
      {:error, "你的真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "piaoxue-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "piaoxue-zhang" do
      :ok
    else
      {:error, "你没有激发飘雪穿云掌，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "piaoxue-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared != nil and hd(String.split(prepared, "/")) == "piaoxue-zhang" do
      :ok
    else
      {:error, "你没有准备使用飘雪穿云掌，无法施展#{@move_name}。\n"}
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
    # LPC: msg = HIW "$N" HIW "一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬"
    #            "间连续攻出数招。\n" NOR;
    #      message_combatd(msg, me);
    #      me->add("neili", -100);
    #      … 3 招（目标侧结算）…
    #      me->start_busy(2 + random(3));
    conn =
      Broadcast.publish(
        conn,
        "$N一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬间连续攻出数招。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(2 + random(3));
    combat = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, 3))
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
    bonuses = Map.get(data, :bonuses, @attack_bonus)
    level = Stats.skill(character.meta.stats, "piaoxue-zhang")
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: 第一招 apply/attack +30；第二招 +90；第三招 +180
    #      （每招一次 COMBAT_D->do_attack(me, target, weapon, 0)）
    # 折算：每击 level/15 基础伤害 + 命中判定（ap/2 + 累计加成 + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(bonuses, {character.meta.combat, 0}, fn bonus, {combat_acc, damage_acc} ->
        if div(ap, 2) + bonus + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(level, 15), 1)
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
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YUN "「" HIW "云海明灯" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/piaoxue-zhang/yun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YUN "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") ||
  #             me->query_temp("secondary_weapon"))
  #                 return notify_fail("你必须空手才能施展" YUN "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，无法施展" YUN "。\n");
  # 
  #         if (me->query_skill("piaoxue-zhang", 1) < 150)
  #                 return notify_fail("你的飘雪穿云掌修为不够，无法施展" YUN "。\n");
  # 
  #         if (me->query("neili") < 200 || me->query("max_neili") < 2000)
  #                 return notify_fail("你的真气不够，无法施展" YUN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "piaoxue-zhang")
  #                 return notify_fail("你没有激发飘雪穿云掌，无法施展" YUN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "piaoxue-zhang")
  #                 return notify_fail("你没有准备使用飘雪穿云掌，无法施展" YUN "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬"
  #               "间连续攻出数招。\n" NOR;
  #     message_combatd(msg, me);
  # 
  #     me->add("neili", -100);
  # 
  #         // 第一招
  #         me->add_temp("apply/attack", 30);
  #           COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 第二招
  #         me->add_temp("apply/attack", 60);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 第三招
  #         me->add_temp("apply/attack", 90);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         // 消除攻击修正
  #         me->add_temp("apply/attack", -180);
  # 
  #     me->start_busy(2 + random(3));
  # 
  #     return 1;
  # }
end
