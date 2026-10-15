defmodule Kantele.Combat.Skills.Performs.HuifengJian.Jue do
  @moduledoc """
  绝剑「jue」（对照 `kungfu/skill/huifeng-jian/jue.c`）

  回风拂柳剑法绝技：需持剑、激发 sword 为回风拂柳剑法、回风拂柳剑法>=120、
  内功>=200、真气>=500、目标存活。共五招，依次以攻击方臂力/悟性/根骨/身法/
  剑法对目标臂力/悟性/根骨/身法/招架判定，命中按 `do_damage(WEAPON_ATTACK,
  damage, pct)` 结算（pct 依次 10/10/15/20/20）。收招扣 400+random(100) 内力，
  忙乱 2+random(5)。

  差异（TODO(migrate)）：
  - 五招的 do_damage 在目标侧依次结算，真力消耗累加后一次性 feedback；
  - 首招引子在攻击方广播，其余四招引子与全部结果在目标侧广播。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "huifeng-jian/jue"
  @move_name "「绝剑」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_mapped(stats),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huifeng-jian" do
      :ok
    else
      {:error, "你没有激发回风拂柳剑法，无法施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huifeng-jian")

    if level < 120 do
      {:error, "你回风拂柳剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你内功火候不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, weapon) do
    stats = character.meta.stats
    weapon_name = Map.get(weapon, :name, "")

    text =
      Enum.join(
        [
          "$N一声暴喝，手中的",
          weapon_name,
          "对准$n直劈而下，正是回风拂柳剑「",
          "绝剑",
          "」绝技。\n"
        ],
        ""
      )

    conn = Broadcast.publish(conn, text, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        str: Stats.query_str(stats),
        int: Stats.query_int(stats),
        con: Stats.query_con(stats),
        dex: Stats.query_dex(stats),
        sword: Stats.skill(stats, "sword"),
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    weapon_name = Map.get(data, :weapon_name, "")
    level = Map.get(data, :level, 0)
    damage = div(level, 2) + Engine.rand(rng, max(div(div(level, 2), 2), 1))

    # 第一招：臂力对臂力（外伤 10）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        ap: Map.get(data, :str, 0),
        dp: Stats.query_str(stats),
        damage: damage,
        pct: 10,
        hit_msg: "$p奋力抵挡，却哪里招架得住，被$P这一剑劈下，登时鲜血迸流！\n",
        miss_msg: "$p嘿的一声，硬声声将$P这一剑架开，丝毫无损。\n"
      })

    # 第二招：悟性对悟性（外伤 10）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        lead:
          "$N随即一声冷笑，手中的" <>
            weapon_name <> "伸伸缩缩，吞吞吐吐，变幻莫测，层层剑光笼罩$n。\n",
        ap: Map.get(data, :int, 0),
        dp: Stats.query_int(stats),
        damage: damage,
        pct: 10,
        hit_msg: "$p大惑不解，一时难以勘透其中奥妙，一连中了几招，身披数创！\n",
        miss_msg: "$p淡淡一笑，浑然不将$P玄妙的招数放在眼中，随意将之架开。\n"
      })

    # 第三招：根骨对根骨（外伤 15）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        lead:
          "$N深深吸了一口气，手中的" <>
            weapon_name <> "幻化出一层浅浅的光芒，人剑合一扑向$n而去。\n",
        ap: Map.get(data, :con, 0),
        dp: Stats.query_con(stats),
        damage: damage,
        pct: 15,
        hit_msg: "$p运气抵挡，只觉得一股透体凉意袭了上来，一个激凌，丹田立刻变得空空荡荡！\n",
        miss_msg: "$p一口气自丹田运了上来，$P附体剑芒虽然厉害，却未能伤$p分毫。\n"
      })

    # 第四招：身法对身法（外伤 20）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        lead:
          "$N脚步一晃，忽然近上身来，身法奇快，手中的" <>
            weapon_name <> "应声而起，刺向$n。\n",
        ap: Map.get(data, :dex, 0),
        dp: Stats.query_dex(stats),
        damage: damage,
        pct: 20,
        hit_msg: "$p只是慢了一步，登时被$P这一剑刺了个正中，鲜血四处飞射！\n",
        miss_msg: "$p身法却是更快，只是一退，让$P这一招堪勘不能奏效。\n"
      })

    # 第五招：剑法对招架（外伤 20）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        lead:
          "$N一声长叹，眼神变得寒冷无情，" <>
            weapon_name <> "悠悠而转，犹如轻风拂柳，说不清的缠绵之意。\n",
        ap: Map.get(data, :sword, 0),
        dp: Stats.skill(stats, "parry"),
        damage: damage,
        pct: 20,
        hit_msg: "$p只觉得沐浴在风中一般，对这招竟然是无可抵挡，被剑光削了个血肉模糊！\n",
        miss_msg: "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n"
      })

    # LPC: me->start_busy(2 + random(5)); me->add("neili", -400 - random(100));
    Performs.feedback(attacker, 400 + Engine.rand(rng, 100), 2 + Engine.rand(rng, 5))

    put_character(conn, character)
  end

  # 单招结算：命中走 do_damage(WEAPON_ATTACK, damage, pct)，未命中走化解文案。
  defp resolve_stage(conn, character, attacker, rng, opts) do
    ap = max(Map.get(opts, :ap, 0), 1)
    dp = Map.get(opts, :dp, 0)
    bindings = [n1: attacker.name, n2: character.name]

    conn =
      case Map.get(opts, :lead) do
        nil -> conn
        lead -> Broadcast.publish(conn, lead, bindings)
      end

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = Map.get(opts, :damage, 0)
      pct = Map.get(opts, :pct, 0)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * pct, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      conn = Broadcast.publish(conn, Map.get(opts, :hit_msg), bindings)
      {conn, character}
    else
      conn = Broadcast.publish(conn, Map.get(opts, :miss_msg), bindings)
      {conn, character}
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "huifeng-jian/jue",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // jue.c  回风拂柳剑法「绝剑」
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JUE "「" HIW "绝剑" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  #         string wname;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/huifeng-jian/jue"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUE "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，无法施展" JUE "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "huifeng-jian")
  #                 return notify_fail("你没有激发回风拂柳剑法，无法施展" JUE "。\n");
  # 
  #         if ((int)me->query_skill("huifeng-jian", 1) < 120)
  #                 return notify_fail("你回风拂柳剑法不够娴熟，无法施展" JUE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #                 return notify_fail("你内功火候不够，无法施展" JUE "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在真气不够，无法施展" JUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wname = weapon->name();
  # 
  #         //damage = (int)me->query_skill("huifeng-jian", 1) / 3;
  #         damage = (int)me->query_skill("huifeng-jian", 1) / 2;
  #         damage += random(damage / 2);
  # 
  #         // 第一招
  #         ap = me->query_str();
  #         dp = target->query_str();
  #         msg = HIC "$N" HIC "一声暴喝，手中的" + wname + HIC "对准$n" HIC "直劈而"
  #               "下，正是回风拂柳剑「" NOR + HIW "绝剑" NOR + HIC "」绝技。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "$p" HIR "奋力抵挡，却哪里招架得住，被$P"
  #                                            HIR "这一剑劈下，登时鲜血迸流！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "嘿的一声，硬声声将$P"
  #                        CYN "这一剑架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         // 第二招
  #         ap = me->query_int();
  #         dp = target->query_int();
  #         msg += "\n" HIC "$N" HIC "随即一声冷笑，手中的" + wname +
  #                HIC "伸伸缩缩，吞吞吐吐，变幻莫测，层层剑光笼罩$n" HIC "。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "$p" HIR "大惑不解，一时难以勘透其"
  #                                            "中奥妙，一连中了几招，身披数创！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "淡淡一笑，浑然不将$P"
  #                 CYN "玄妙的招数放在眼中，随意将之架开。\n" NOR;
  #         }
  # 
  #         // 第三招
  #         ap = me->query_con();
  #         dp = target->query_con();
  #         msg += "\n" HIC "$N" HIC "深深吸了一口气，手中的" + wname +
  #                HIC "幻化出一层浅浅的光芒，人剑合一扑向$n" HIC "而去。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 15,
  #                                            HIR "$p" HIR "运气抵挡，只觉得一股透体凉意"
  #                                            "袭了上来，一个激凌，丹田立刻变得空空荡荡！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "一口气自丹田运了上来，$P"
  #                 CYN "附体剑芒虽然厉害，却未能伤$p" CYN "分毫。\n" NOR;
  #         }
  # 
  #         // 第四招
  #         ap = me->query_dex();
  #         dp = target->query_dex();
  #         msg += "\n" HIC "$N" HIC "脚步一晃，忽然近上身来，身法奇快，手中的" + wname +
  #                HIC "应声而起，刺向$n" HIC "。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
  #                                            HIR "$p" HIR "只是慢了一步，登时被$P"
  #                                            HIR "这一剑刺了个正中，鲜血四处飞射！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "身法却是更快，只是一退，让$P"
  #                 CYN "这一招堪勘不能奏效。\n" NOR;
  #         }
  # 
  #         // 第五招
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #         msg += "\n" HIC "$N" HIC "一声长叹，眼神变得寒冷无情，" + wname +
  #                HIC "悠悠而转，犹如轻风拂柳，说不清的缠绵之意。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
  #                                            HIR "$p" HIR "只觉得沐浴在风中一般，对这招竟然是无可抵挡，被"
  #                                            HIR "剑光削了个血肉模糊！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #         }
  # 
  #         me->start_busy(2 + random(5));
  #         me->add("neili", -400 - random(100));
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
