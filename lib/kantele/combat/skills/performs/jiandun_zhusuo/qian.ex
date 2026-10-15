defmodule Kantele.Combat.Skills.Performs.JiandunZhusuo.Qian do
  @moduledoc """
  千头万绪「qian」（对照 `kungfu/skill/jiandun-zhusuo/qian.c`）

  剑盾珠索三连击：需持鞭、内功>=180、剑盾珠索>=120、真气>=400、激发 whip 为
  剑盾珠索、目标存活。三鞭均以攻击方 whip 等级对目标 parry/dodge/force 判定，
  命中按 `do_damage(WEAPON_ATTACK, damage, 10)` 结算；伤害
  `damage = 剑盾珠索/4 + random(/16)`。收招扣 300 内力，忙乱 3+random(3)。

  差异（TODO(migrate)）：
  - 三鞭的 do_damage 在目标侧依次结算，真力消耗累加后一次性 feedback；
  - 首招引子在攻击方广播，其余两招引子与全部结果在目标侧广播。
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

  @perform_id "jiandun-zhusuo/qian"
  @move_name "「千头万绪」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
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

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "jiandun-zhusuo")

    if level < 120 do
      {:error, "你的剑盾珠索修为不够，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "jiandun-zhusuo" do
      :ok
    else
      {:error, "你没有激发剑盾珠索，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, level, weapon) do
    stats = character.meta.stats
    weapon_name = Map.get(weapon, :name, "")

    conn =
      Broadcast.publish(
        conn,
        "$N一声轻哼，右手横挥，手中" <> weapon_name <> "一招「千头万绪」对准$n乱点下来。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        whip: Stats.skill(stats, "whip"),
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
    whip = Map.get(data, :whip, 0)
    damage = div(level, 4) + Engine.rand(rng, max(div(div(level, 4), 4), 1))

    # 第一招：对 parry（外伤 10）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        ap: whip,
        dp: Stats.skill(stats, "parry"),
        damage: damage,
        hit_msg: "$p抽身回退，却已然不及，被$P这招点中要穴，顿时口喷鲜血！\n",
        miss_msg: "$p凝神聚气，硬声声将$P这一鞭架开，丝毫无损。\n"
      })

    # 第二招：对 dodge（外伤 10）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        lead:
          "\n却见$N跨步上前，手中" <>
            weapon_name <> "招数一变，反转鞭鞘，抽向$n而去。\n",
        ap: whip,
        dp: Stats.skill(stats, "dodge"),
        damage: damage,
        hit_msg: "便在$p微微一楞间，已被$P这招抽中，鲜血四处飞溅！\n",
        miss_msg: "可是$p急忙猛吸一口气，飞身跃起，躲开了这一招。\n"
      })

    # 第三招：对 force（外伤 10）
    {conn, character} =
      resolve_stage(conn, character, attacker, rng, %{
        lead:
          "\n紧接着又见$N纵身而起，单手将" <>
            weapon_name <> "急速舞动，凌空朝着$n圈去。\n",
        ap: whip,
        dp: Stats.skill(stats, "force"),
        damage: damage,
        hit_msg: "顿时便听“啪”的一声闷响，$n竟被" <> weapon_name <> "卷至半空，重重摔下，再也无力爬起！\n",
        miss_msg: "可$p一个翻滚，起身时已在丈许开外，便将这式化解于无形。\n"
      })

    # LPC: me->start_busy(3 + random(3)); me->add("neili", -300);
    Performs.feedback(attacker, 300, 3 + Engine.rand(rng, 3))

    put_character(conn, character)
  end

  # 单招结算：命中走 do_damage(WEAPON_ATTACK, damage, 10)，未命中走化解文案。
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

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 10, 100))

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
      id: "jiandun-zhusuo/qian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QIAN "「" HIW "千头万绪" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/jiandun-zhusuo/qian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功的修为不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("jiandun-zhusuo", 1) < 120)
  #                 return notify_fail("你的剑盾珠索修为不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "jiandun-zhusuo")
  #                 return notify_fail("你没有激发剑盾珠索，难以施展" QIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wname = weapon->name();
  # 
  #         damage = me->query_skill("jiandun-zhusuo", 1) / 4;
  #         damage += random(damage / 4);
  # 
  #         ap = me->query_skill("whip");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIW "$N" HIW "一声轻哼，右手横挥，手中" + wname +
  #               HIW "一招「千头万绪」对准$n" HIW "乱点下来。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "$p" HIR "抽身回退，却已然不及，被"
  #                                            "$P" HIR "这招点中要穴，顿时口喷鲜血！\n"
  #                                            NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "凝神聚气，硬声声将$P"
  #                        CYN "这一鞭架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("whip");
  #         dp = target->query_skill("dodge");
  # 
  #         msg += "\n" HIW "却见$N" HIW "跨步上前，手中" + wname +
  #                HIW "招数一变，反转鞭鞘，抽向$n" HIW "而去。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "便在$p" HIR "微微一楞间，已被$P"
  #                                            HIR "这招抽中，鲜血四处飞溅！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "急忙猛吸一口气，飞"
  #                        "身跃起，躲开了这一招。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("whip");
  #         dp = target->query_skill("force");
  # 
  #         msg += "\n" HIW "紧接着又见$N" HIW "纵身而起，单手将" + wname +
  #                HIW "急速舞动，凌空朝着$n" HIW "圈去。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
  #                                            HIR "顿时便听“啪”的一声闷响，$n" HIR
  #                                            "竟被" + wname + HIR "卷至半空，重重"
  #                                            "摔下，再也无力爬起！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可$p" CYN "一个翻滚，起身时已在"
  #                        "丈许开外，便将这式化解于无形。\n" NOR;
  #         }
  #         me->start_busy(3 + random(3));
  #         me->add("neili", -300);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
