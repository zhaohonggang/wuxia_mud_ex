defmodule Kantele.Combat.Skills.Performs.PoshuiZhang.Tai do
  @moduledoc """
  perform「泰山压顶」（对照 `kungfu/skill/poshui-zhang/tai.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 →
  武器为 staff → 内功>=180 → 真气>=300 → 八十一路泼水杖>=120 →
  激发 staff 为八十一路泼水杖 → 目标存活。
  起手广播（带武器名）后由目标侧单次判定
  `ap/2 + random(ap) > 目标招架`：命中则
  `damage = ap + random(ap/2)`、外伤比例 45、攻击方 `start_busy(3)`
  并扣真气 180；未命中则 `start_busy(4)` 并扣真气 100。
  两种消耗都依赖命中结果，故经 `Performs.feedback(attacker, neili, busy)`
  在目标侧回授。

  差异（TODO(migrate)）：
  - `.c` 在选目标时先 `clean_up_enemy()` 再 `select_opponent()`；框架侧由
    `combat.enemies` 直接提供当前对手，无对应清理动作（信息性差异）；
  - `.c` 的 `message_sort` 起手与 `message_vision` 分支文案分两次广播；
    E 侧同样拆两处——起手在攻击方发布，命中/未命中文案在目标侧发布
    （`dp` 需目标属性）；
  - `.c` 起手文案 `"…手中" + weapon->name() + HIW "从天而降…"` 为两段字面量
    拆段，E 侧写 `"…手中" <> weapon_name <> "从天而降…"`（不合并成单段）；
  - `.c` 起手文案以 `\n` 开头、结尾有换行，逐字保留；未命中文案的
    「好不容易」与 .c 一致（.c 是「好不容」+「易抵挡住了」跨段拼接）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "poshui-zhang/tai"
  @move_name "「泰山压顶」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("staff");
    ap = Stats.skill(stats, "staff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
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

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/poshui-zhang/tai"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #       || (string)weapon->query("skill_type") != "staff")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 180)
  #      if ((int)me->query("neili") < 300)
  #      if ((int)me->query_skill("poshui-zhang", 1) < 120)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      character.meta.vitals.neili < 300 ->
        {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "poshui-zhang") < 120 ->
        {:error, "你八十一路泼水杖火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "poshui-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "staff") == "poshui-zhang" do
      :ok
    else
      {:error, "你没有激发八十一路泼水杖，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target))
  #      return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

  # LPC: msg = HIW "\n$N" HIW "一声暴喝，猛然间腾空而起，手中"
  #            + weapon->name() + HIW "从天而降，气势惊人，"
  #            "犹如泰山压顶般地袭向$n" HIW "。\n" NOR;
  #      message_sort(msg, me, target);
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      "\n$N一声暴喝，猛然间腾空而起，手中" <>
        weapon_name(character.meta.combat) <>
        "从天而降，气势惊人，犹如泰山压顶般地袭向$n。\n",
      n1: character.name,
      n2: target.name
    )
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      #      msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
      #                                HIR "$n" HIR "完全无法看清招中虚实，只"
      #                                "听「砰砰砰」几声，已被$N" HIR "击中数"
      #                                "杖。\n" NOR);
      #      me->start_busy(3);
      #      me->add("neili", -180);
      damage = ap + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 180, 3)

      conn
      |> Broadcast.publish(
        "$n完全无法看清招中虚实，只听「砰砰砰」几声，已被$N击中数杖。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg = CYN "可是$n" CYN "奋力招架，左闪右避，好不容"
      #             "易抵挡住了$N" CYN "的攻击。\n" NOR;
      #      me->start_busy(4);
      #      me->add("neili", -100);
      Performs.feedback(attacker, 100, 4)

      conn
      |> Broadcast.publish("可是$n奋力招架，左闪右避，好不容易抵挡住了$N的攻击。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TAI "「" HIW "泰山压顶" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp, damage;
  #  
  #         if (userp(me) && ! me->query("can_perform/poshui-zhang/tai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TAI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你使用的武器不对，难以施展" TAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功火候不够，难以施展" TAI "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" TAI "。\n");
  # 
  #         if ((int)me->query_skill("poshui-zhang", 1) < 120)
  #                 return notify_fail("你八十一路泼水杖火候不够，难以施展" TAI "。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "poshui-zhang") 
  #                 return notify_fail("你没有激发八十一路泼水杖，难以施展" TAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "一声暴喝，猛然间腾空而起，手中" 
  #               + weapon->name() + HIW "从天而降，气势惊人，"
  #               "犹如泰山压顶般地袭向$n" HIW "。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
  #                                            HIR "$n" HIR "完全无法看清招中虚实，只"
  #                                            "听「砰砰砰」几声，已被$N" HIR "击中数"
  #                                            "杖。\n" NOR);
  #                 me->start_busy(3);
  #                 me->add("neili", -180);
  #         } else 
  #         {
  #                 msg = CYN "可是$n" CYN "奋力招架，左闪右避，好不容"
  #                        "易抵挡住了$N" CYN "的攻击。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
