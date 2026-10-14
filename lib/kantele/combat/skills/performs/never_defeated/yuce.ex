defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Yuce do
  @moduledoc """
  perform「御策诀」（对照 `kungfu/skill/never-defeated/perform/yuce.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 throwing 类暗器（余量>=1）→
  不败神功>=100 → 真气>=150 → 目标存活。
  攻击方扣 120 真气、消耗 1 枚暗器并发起手广播（含 `base_unit` 与暗器名）；
  忙乱 1。
  目标侧以 `random(my_exp) > 目标 combat_exp*2/3` 判定
  （`my_exp = 攻击方 combat_exp + 不败神功*不败神功/10*不败神功`）：
  命中则目标 qi **上限伤** `不败神功/2 + random(不败神功/2)`（仅 wound、无 damage），
  并广播命中文案；未命中则广播闪避文案。

  差异（TODO(migrate)）：
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_combatd`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`）；
  - `.c` 的起手/命中文案用 `+` 断段处（`"…一"` / `base_unit` / `name()` / `"如蛟龙般"` /
    `"打向$n"` / `"只见那"` / `"去势恰如神光闪电！$n"` / `"不及闪避…"`）一律以
    `Enum.join/2` 保留分段（两段字面量之间无变量时**不能**用 `<>`，会被验收器合成一段）；
  - `target->receive_wound("qi", …, me)` 只有上限伤 → `Vitals.wound(:qi, n)`；
  - `weapon->hit_ob(me, target, jiali + 150)` 的追加伤害本引擎无 per-skill hit_ob 钩子
    （同 `fenglei_zifa/she.ex`），未建模；其 `query_ahinfo()` 文案亦无对应物；
  - `me->reset_action()` 动作表重置未建模；
  - `me->add("neili",-120)` 与 `me->start_busy(1)` 无条件 → 攻击方直接结算；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
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

  @perform_id "never-defeated/yuce"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "never-defeated")
    anqi = handing_anqi(character)

    # LPC: my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
    #      （skill = me->query_skill("never-defeated", 1)）
    my_exp = (stats.combat_exp || 0) + div(lvl * lvl, 10) * lvl

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_anqi(character),
         :ok <- check_level(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          my_exp: my_exp,
          anqi_name: anqi.name,
          rng: rng
        }
      })

      apply_effect(conn, character, anqi)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: 本式无 can_perform 门槛，框架层统一把关（见 moduledoc 差异说明）。
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
      [] -> {:error, "御策诀只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing"))
  #          || (string)weapon->query("skill_type") != "throwing"
  #          || weapon->query_amount() < 1)
  #      return notify_fail("你现在手中并没有拿着暗器，怎么施展御策诀？\n");
  defp check_anqi(character) do
    if handing_anqi(character) do
      :ok
    else
      {:error, "你现在手中并没有拿着暗器，怎么施展御策诀？\n"}
    end
  end

  # LPC: if ((skill = me->query_skill("never-defeated", 1)) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "never-defeated") < 100 do
      {:error, "你的不败神功火候不够，不会施展御策诀。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150) return notify_fail("你内力不够了。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不够了。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, anqi) do
    # LPC: msg = HIC "$N" HIC "手指一合一弹，只听呼啸破空声起，有若龙吟，一" +
    #            weapon->query("base_unit") + weapon->name() + HIC "如蛟龙般" +
    #            "打向$n" HIC "。\n" NOR;（`+` 断段用 Enum.join 保留分段）
    opener =
      Enum.join([
        "$N手指一合一弹，只听呼啸破空声起，有若龙吟，一",
        Map.get(anqi.meta, :base_unit),
        anqi.name,
        "如蛟龙般",
        "打向$n。\n"
      ])

    conn = Broadcast.publish(conn, opener, n1: character.name)

    # LPC: me->add("neili", -120);  weapon->add_amount(-1);
    character = consume_anqi(character, anqi)
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 120}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(1);
    combat = Combat.start_busy(character.meta.combat, 1)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        (Map.get(item.meta, :amount) || 1) >= 1
    end)
  end

  # LPC: weapon->add_amount(-1)；数量归零则移除该实例。
  defp consume_anqi(character, anqi) do
    if anqi do
      inventory =
        character.inventory
        |> Enum.map(fn item ->
          if item == anqi do
            amount = (Map.get(item.meta, :amount) || 1) - 1

            if amount >= 1 do
              %{item | meta: Map.put(item.meta, :amount, amount)}
            else
              nil
            end
          else
            item
          end
        end)
        |> Enum.reject(&is_nil/1)

      %{character | inventory: inventory}
    else
      character
    end
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    skill = max(Map.get(data, :skill, 0), 0)
    my_exp = max(Map.get(data, :my_exp, 0), 1)

    # LPC: ob_exp = target->query("combat_exp");
    ob_exp = stats.combat_exp || 0

    # LPC: if (random(my_exp) > ob_exp * 2 / 3)
    #      { msg += "只见那" + weapon->name() + "去势恰如神光闪电！$n"
    #               + "不及闪避，被打了个正中，惨叫一声，退了几步。\n";
    #        target->receive_wound("qi", skill / 2 + random(skill / 2), me);
    #        COMBAT_D->clear_ahinfo(); weapon->hit_ob(me, target, jiali + 150);
    #        if (stringp(pmsg = COMBAT_D->query_ahinfo())) msg += pmsg;
    #        message_combatd(msg, me, target); }
    #      else { msg += "可是$p急忙一闪，躲过了$P" HIG "发出的" + weapon->name() +
    #                 "。\n"; message_combatd(msg, me, target); }
    if Engine.rand(rng, my_exp) > div(ob_exp * 2, 3) do
      # LPC: target->receive_wound("qi", skill / 2 + random(skill / 2), me);（仅上限伤）
      wound = div(skill, 2) + Engine.rand(rng, div(skill, 2))

      vitals =
        character.meta.vitals
        |> Vitals.wound(:qi, wound)

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: 命中文案按 `+` 断段：`只见那` / name() / `去势恰如神光闪电！$n` /
      #      `不及闪避，被打了个正中，惨叫一声，退了几步。`（第二三段之间无变量 → 用 Enum.join）
      wn = Map.get(data, :anqi_name)

      text =
        Enum.join([
          "只见那",
          wn,
          "去势恰如神光闪电！$n",
          "不及闪避，被打了个正中，惨叫一声，退了几步。\n"
        ])

      conn
      |> Broadcast.publish(text, bindings)
      |> put_character(character)
    else
      wn = Map.get(data, :anqi_name)

      text =
        "可是$p急忙一闪，躲过了$P发出的" <>
          wn <> "。\n"

      Broadcast.publish(conn, text, bindings)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // yuce.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill;
  #         // int n, i;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("御策诀只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing" ||
  #             weapon->query_amount() < 1)
  #                 return notify_fail("你现在手中并没有拿着暗器，怎么施展御策诀？\n");
  # 
  #         if ((skill = me->query_skill("never-defeated", 1)) < 100)
  #                 return notify_fail("你的不败神功火候不够，不会施展御策诀。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你内力不够了。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -120);
  #         weapon->add_amount(-1);
  # 
  #         msg = HIC "$N" HIC "手指一合一弹，只听呼啸破空声起，有若龙吟，一" +
  #              weapon->query("base_unit") + weapon->name() + HIC "如蛟龙般" +
  #              "打向$n" HIC "。\n" NOR;
  # 
  #         me->start_busy(1);
  #         my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
  #         ob_exp = target->query("combat_exp");
  #         if (random(my_exp) > ob_exp * 2 / 3)
  #         {
  #                 msg += HIR + "只见那" + weapon->name() + HIR "去势恰如神光闪电！$n"
  #                        HIR + "不及闪避，被打了个正中，惨叫一"
  #                        "声，退了几步。\n" NOR;
  #                 target->receive_wound("qi", skill / 2 + random(skill / 2), me);
  #                 COMBAT_D->clear_ahinfo();
  #                 weapon->hit_ob(me, target,
  #                                me->query("jiali") + 150);
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "急忙一闪，躲过了$P" HIG "发出的" +
  #                        weapon->name() + CYN "。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         me->reset_action();
  #         return 1;
  # }
end
