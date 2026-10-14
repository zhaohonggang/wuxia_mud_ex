defmodule Kantele.Combat.Skills.Performs.PanguQishi.Kai do
  @moduledoc """
  perform「开天辟地」（对照 `kungfu/skill/pangu-qishi/kai.c`）

  门槛（按 .c 顺序）：已学此招（`.c` 的 `userp(me) && !can_perform`，文案即
  「你所使用的外功中没有这种功能。」）→ 战斗中的对手 → 持锤
  （`skill_type == "hammer"`）→ 内功>=300 → 盘古七势>=180 → 真气>=400 →
  激发 hammer 为盘古七势 → 目标存活。
  起手广播后由目标侧结算：`ap = 锤法 + 膂力*10`、`dp = 目标内功 + 根骨*10`，
  `ap/2 + random(ap) > dp` 命中则 `damage = ap/2 + random(ap)`、攻击方扣 500
  真气并忙乱 3 回合、目标受 `do_damage(WEAPON_ATTACK, damage, 80)`；
  否则攻击方扣 300 真气并忙乱 4 回合、广播「如中败絮」文案。

  差异（TODO(migrate)）：
  - `ap` 含攻击方 `str`，只能由攻击方计算并经事件 data 传给目标侧；
    `dp` 含目标 `con`，在目标侧计算（同 `riyue_lun/po.ex` 的形状）；
  - 两条分支的 neili 消耗/忙乱为命中相关，故经
    `Performs.feedback(attacker, neili, busy)` 回授攻击方；
  - `COMBAT_D->do_damage(..., 80, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 80, 100))`；
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
  alias Kantele.Combat.Performs

  @perform_id "pangu-qishi/kai"
  @move_name "「开天辟地」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("hammer") + me->query("str") * 10;
    ap = Stats.skill(stats, "hammer") + Stats.query_str(stats) * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
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

      apply_effect(conn, character, target, weapon_name(combat))
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/pangu-qishi/kai"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "hammer")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "hammer" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 300)
  #      if (me->query_skill("pangu-qishi", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "pangu-qishi") < 180 ->
        {:error, "你的盘古七势修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hammer") != "pangu-qishi")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hammer") == "pangu-qishi" do
      :ok
    else
      {:error, "你没有激发盘古七势，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target, wn) do
    # LPC: msg = WHT "$N" WHT "一声断喝，手中" + weapon->name() +
    #            WHT "如山岳巍峙，携着开天辟地之势向$n" WHT "猛劈而下！\n" NOR;
    #      ap/dp 之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
    conn =
      Broadcast.publish(
        conn,
        "$N一声断喝，手中" <> wn <> "如山岳巍峙，携着开天辟地之势向$n猛劈而下！\n",
        n1: character.name,
        n2: target.name
      )

    put_character(conn, character)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
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

    # LPC: dp = target->query_skill("force") + target->query("con") * 10;
    stats = character.meta.stats
    dp = Stats.skill(stats, "force") + Stats.query_con(stats) * 10

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap / 2 + random(ap);  me->add("neili", -500);
    #        me->start_busy(3);
    #        msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
    #                    HIR "$n" HIR "躲避不及，被$N" HIR "这"
    #                    "锤正中胸口，顿时一声闷响，稻草般向后"
    #                    "横飞出去。\n" NOR); }
    #      else
    #      { me->add("neili", -300);  me->start_busy(4);
    #        msg += HIC "可是$n" HIC "真气鼓荡，$N" HIC "雷霆般"
    #               "的劲力竟如中败絮，登时被解于无形。\n" NOR; }
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    {conn, character} =
      if hit do
        damage = div(ap, 2) + Engine.rand(rng, ap)
        vitals = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 80, 100))
        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 500, 3)

        conn =
          Broadcast.publish(
            conn,
            "$n躲避不及，被$N这锤正中胸口，顿时一声闷响，稻草般向后横飞出去。\n",
            bindings
          )

        {conn, character}
      else
        Performs.feedback(attacker, 300, 4)

        conn =
          Broadcast.publish(
            conn,
            "可是$n真气鼓荡，$N雷霆般的劲力竟如中败絮，登时被解于无形。\n",
            bindings
          )

        {conn, character}
      end

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KAI "「" HIY "开天辟地" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/pangu-qishi/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "hammer")
  #                 return notify_fail("你使用的武器不对，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功的修为不够，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill("pangu-qishi", 1) < 180)
  #                 return notify_fail("你的盘古七势修为不够，难以施展" KAI "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "pangu-qishi")
  #                 return notify_fail("你没有激发盘古七势，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "一声断喝，手中" + weapon->name() +
  #               WHT "如山岳巍峙，携着开天辟地之势向$n" WHT "猛劈而下！\n" NOR;
  # 
  #         ap = me->query_skill("hammer") + me->query("str") * 10;
  #         dp = target->query_skill("force") + target->query("con") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 me->add("neili", -500);
  #                 me->start_busy(3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "躲避不及，被$N" HIR "这"
  #                                            "锤正中胸口，顿时一声闷响，稻草般向后"
  #                                            "横飞出去。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -300);
  #                 me->start_busy(4);
  #                 msg += HIC "可是$n" HIC "真气鼓荡，$N" HIC "雷霆般"
  #                        "的劲力竟如中败絮，登时被解于无形。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
