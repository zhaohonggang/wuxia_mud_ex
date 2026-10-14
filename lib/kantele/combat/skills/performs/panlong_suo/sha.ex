defmodule Kantele.Combat.Skills.Performs.PanlongSuo.Sha do
  @moduledoc """
  perform「绝命七杀」（对照 `kungfu/skill/panlong-suo/sha.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 持鞭
  （`skill_type == "whip"`）→ 内功>=220 → 霹雳盘龙索>=180 → 激发 whip 为
  霹雳盘龙索 → 真气>=300 → 目标存活。
  起手广播后由目标侧判定 `random(鞭法) > 目标招架/2`：命中则广播「手忙脚乱…」
  并取 `count = 鞭法/20`，否则广播「全神应对…」且 `count = 0`；攻击方扣 180
  真气，随后连出 6 击（每击 1/3 概率令未忙乱的目标忙乱 1 回合），
  收招忙乱 `1 + random(6)`。

  差异（TODO(migrate)）：
  - `me->add_temp("apply/attack", ±count)` 的临时加成折入目标侧逐击命中判定
    （攻击方本地 temp 对远程结算无意义），收招的 `-count` 不再重复落账
    （同 `luoyan_jian/luo.ex`）；
  - `.c` 的 `me->start_busy(1 + random(6))` 位于 6 击之后，而 E 侧起手效果与
    目标侧连击是两个异步事件，故收敛在攻击方 apply_effect 中统一结算；
  - `.c` 的 `random(鞭法) > 招架/2` 分支文案需目标侧招架，故在目标侧广播；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底；
  - 起手文案按 `.c` 原样以 `weapon->name()` 为界拆为两段字面量。
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

  @perform_id "panlong-suo/sha"
  @move_name "「绝命七杀」"

  # LPC: for (i = 0; i < 6; i++) COMBAT_D->do_attack(me, target, weapon, 0);
  @strikes 6

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("whip")) —— 分支判定用鞭法等级。
    ap = Stats.skill(stats, "whip")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
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

  # LPC: if (userp(me) && ! me->query("can_perform/panlong-suo/sha"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "whip" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 220)
  #      if (me->query_skill("panlong-suo", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 220 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "panlong-suo") < 180 ->
        {:error, "你的霹雳盘龙索还不到家，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("whip") != "panlong-suo")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "whip") == "panlong-suo" do
      :ok
    else
      {:error, "你没有激发霹雳盘龙索，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIR "突然间$N" HIR "猛的猱身扑上，手中" + weapon->name() +
    #            HIR "急转，便似不要命般地向$n" HIR "猛攻过去。\n" NOR;
    #      message_combatd(msg, me, target);
    #      me->add("neili", -180);
    #      … 6 击（目标侧结算）…
    #      me->start_busy(1 + random(6));
    wn =
      case Combat.weapon(character.meta.combat) do
        nil -> ""
        weapon -> Map.get(weapon, :name)
      end

    conn =
      Broadcast.publish(
        conn,
        "突然间$N猛的猱身扑上，手中" <> wn <> "急转，便似不要命般地向$n猛攻过去。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -180);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 180, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(1 + random(6));
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 6))
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

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    level = Stats.skill(character.meta.stats, "panlong-suo")
    dodge = Stats.skill(character.meta.stats, "dodge")
    parry = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("whip")) > target->query_skill("parry") / 2)
    #      { msg += "$n卒不及防，登时手忙脚乱，招架疏散，慌忙中难以抵挡。\n";
    #        count = me->query_skill("whip") / 20; }
    #      else
    #      { msg += "$n心底一惊，连忙全神应对，不敢有丝毫大意。\n";
    #        count = 0; }
    #      message_combatd(msg, me, target);
    {conn, count} =
      if Engine.rand(rng, ap) > div(parry, 2) do
        conn =
          Broadcast.publish(
            conn,
            "$n卒不及防，登时手忙脚乱，招架疏散，慌忙中难以抵挡。\n",
            bindings
          )

        {conn, div(ap, 20)}
      else
        conn =
          Broadcast.publish(
            conn,
            "$n心底一惊，连忙全神应对，不敢有丝毫大意。\n",
            bindings
          )

        {conn, 0}
      end

    # LPC: for (i = 0; i < 6; i++) { if (! me->is_fighting(target)) break;
    #            if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
    #            COMBAT_D->do_attack(me, target, weapon, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（ap/2 + count + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc =
          if Engine.rand(rng, 3) == 1 and not Combat.busy?(combat_acc) do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
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
  # 
  # #define SHA "「" HIR "绝命七杀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #         int count;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/panlong-suo/sha"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(SHA "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对，难以施展" SHA "。\n");
  # 
  #     if ((int)me->query_skill("force") < 220)
  #         return notify_fail("你的内功火候不够，难以施展" SHA "。\n");
  # 
  #     if ((int)me->query_skill("panlong-suo", 1) < 180)
  #         return notify_fail("你的霹雳盘龙索还不到家，难以施展" SHA "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "panlong-suo")
  #                 return notify_fail("你没有激发霹雳盘龙索，难以施展" SHA "。\n");
  # 
  #     if ((int)me->query("neili") < 300)
  #         return notify_fail("你的真气不够，难以施展" SHA "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "突然间$N" HIR "猛的猱身扑上，手中" + weapon->name() +
  #               HIR "急转，便似不要命般地向$n" HIR "猛攻过去。\n" NOR;
  # 
  #         if (random(me->query_skill("whip")) > target->query_skill("parry") / 2)
  #         {
  #                 msg += HIR "$n" HIR "卒不及防，登时手忙脚乱，招架疏"
  #                        "散，慌忙中难以抵挡。\n" NOR;
  #                 count = me->query_skill("whip") / 20;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "心底一惊，连忙全神应对，不敢有"
  #                        "丝毫大意。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -180);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(6));
  #     return 1;
  # }
end
