defmodule Kantele.Combat.Skills.Performs.LeitingFu.Sanda do
  @moduledoc """
  perform「三板斧」（source leiting-fu/sanda.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 持锤类武器 → 激发 hammer 为雷霆斧法 →
  臂力>=40 → 内功>=200 → 锤法>=180 → 真气>=500 → 目标存活。
  三斧依次「劈脑袋 / 鬼剔牙 / 掏耳朵」，各斧独立命中判定：
    1) ap=锤法+臂力*2 vs 目标 force，命中 `ap*2/3+random(ap)`；
    2) ap+=身法*3 vs 目标 parry，命中 `ap/2+random(ap*4/5)`；
    3) ap+=根骨*5 vs 目标 dodge，命中 `ap/3+random(ap*3/5)`。
  伤害按 `do_damage(WEAPON_ATTACK, damage, count)` 结算（count 为外伤比例），
  命中扣真气 80/110/140、未命中 40/55/70；收招忙乱 3+random(3)。

  差异（TODO(migrate)）：
  - LPC 无 can_perform 门槛，故无 check_perform_known；
  - `me->query("reborn/count")`（转世次数）框架未建模，zhuan 取 0，
    `属性 - zhuan*20` 的折算结构保留；
  - 三斧的 do_damage 在目标侧依次结算，三斧真力消耗累加后一次性 feedback。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "leiting-fu/sanda"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(character),
         :ok <- check_str(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: Stats.skill(stats, "leiting-fu"),
          skill: Stats.skill(stats, "leiting-fu"),
          hammer: Stats.skill(stats, "hammer"),
          str: Stats.query_str(stats),
          dex: Stats.query_dex(stats),
          con: Stats.query_con(stats),
          damage: Stats.skill(stats, "leiting-fu"),
          rng: rng
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! me->is_fighting())
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「三板斧」只能在战斗中使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #            weapon->query("skill_type") != "hammer")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "hammer" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if (me->query_skill_mapped("hammer") != "leiting-fu")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hammer") == "leiting-fu" do
      :ok
    else
      {:error, "你没有激发雷霆斧法，不能使用「三板斧」。\n"}
    end
  end

  # LPC: if ((int)me->query_str() < 40)
  defp check_str(character) do
    if Stats.query_str(character.meta.stats) < 40 do
      {:error, "你现在的臂力不够，目前不能使用「三板斧」！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force", 1) < 200)
  #         if ((int)me->query_skill("hammer", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，难以施展「三板斧」！\n"}
      Stats.skill(stats, "hammer") < 180 ->
        {:error, "你的棍法修为不够，不会使用「三板斧」！\n"}
      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500)
  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的真气不足！\n"}
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

  # LPC 无条件攻击方效果：无（三斧的内力/忙乱均由目标侧 feedback 回执）。
  defp apply_effect(conn, _character) do
    conn
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
    stats = character.meta.stats
    hammer = Map.get(data, :hammer, 0)
    str = Map.get(data, :str, 0)
    dex = Map.get(data, :dex, 0)
    con = Map.get(data, :con, 0)
    base_damage = Map.get(data, :damage, 0)
    zhuan = 0  # LPC: me->query("reborn/count") 未建模

    # LPC 三斧的 ap / damage / count 依次累加：
    ap1 = hammer + str * 2
    ap2 = ap1 + dex * 3
    ap3 = ap2 + con * 5
    dmg1 = base_damage + (str - zhuan * 20) * 2
    dmg2 = dmg1 + (dex - zhuan * 20) * 3
    dmg3 = dmg2 + (con - zhuan * 20) * 5
    cnt1 = str - zhuan * 20
    cnt2 = cnt1 + dex - zhuan * 20
    cnt3 = cnt2 + con - zhuan * 20

    # 第一斧劈脑袋：ap*2/3 + random(ap) vs force
    {conn, character, n1} = resolve_axe(conn, character, attacker, rng, %{
      lead: "\n$N喝道：劈脑袋！\n",
      hit_msg: "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
      miss_msg: "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
      ap: ap1, dp: Stats.skill(stats, "force"), damage: dmg1, count: cnt1,
      hit: fn r, ap -> div(ap * 2, 3) + Engine.rand(r, ap) end,
      neili_hit: 80, neili_miss: 40
    })

    # 第二斧鬼剔牙：ap/2 + random(ap*4/5) vs parry
    {conn, character, n2} = resolve_axe(conn, character, attacker, rng, %{
      lead: "\n$N喝道：鬼剔牙！\n",
      hit_msg: "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
      miss_msg: "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
      ap: ap2, dp: Stats.skill(stats, "parry"), damage: dmg2, count: cnt2,
      hit: fn r, ap -> div(ap, 2) + Engine.rand(r, div(ap * 4, 5)) end,
      neili_hit: 110, neili_miss: 55
    })

    # 第三斧掏耳朵：ap/3 + random(ap*3/5) vs dodge
    {conn, character, n3} = resolve_axe(conn, character, attacker, rng, %{
      lead: "\n$N喝道：掏耳朵！\n",
      hit_msg: "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
      miss_msg: "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
      ap: ap3, dp: Stats.skill(stats, "dodge"), damage: dmg3, count: cnt3,
      hit: fn r, ap -> div(ap, 3) + Engine.rand(r, div(ap * 3, 5)) end,
      neili_hit: 140, neili_miss: 70
    })

    # LPC: me->start_busy(3 + random(3))（三斧之后）
    Performs.feedback(attacker, n1 + n2 + n3, 3 + Engine.rand(rng, 3))

    conn
    |> put_character(character)
  end

  # 单斧结算：命中走 do_damage(WEAPON_ATTACK, damage, count)，未命中走化解文案。
  defp resolve_axe(conn, character, attacker, rng, opts) do
    ap = max(Map.get(opts, :ap, 0), 1)
    dp = Map.get(opts, :dp, 0)
    hit? = Map.get(opts, :hit).(rng, ap) > dp

    {vitals, msg, neili} =
      if hit? do
        damage = Map.get(opts, :damage, 0)
        count = max(Map.get(opts, :count, 0), 0)
        v = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * count, 100))
        {v, Map.get(opts, :hit_msg), Map.get(opts, :neili_hit, 0)}
      else
        {character.meta.vitals, Map.get(opts, :miss_msg), Map.get(opts, :neili_miss, 0)}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn = Broadcast.publish(conn, Map.get(opts, :lead), n1: attacker.name, n2: character.name)
    conn = Broadcast.publish(conn, msg, n1: attacker.name, n2: character.name)

    {conn, character, neili}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // sanda.c 三板斧
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage, count;
  #         int zhuan;
  # 
  #         zhuan = me->query("reborn/count");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! me->is_fighting())
  #             return notify_fail("「三板斧」只能在战斗中使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #                 (string)weapon->query("skill_type") != "hammer")
  #             return notify_fail("你使用的武器不对。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "leiting-fu")
  #             return notify_fail("你没有激发雷霆斧法，不能使用「三板斧」。\n");
  # 
  #         if ((int)me->query_str() < 40)
  #             return notify_fail("你现在的臂力不够，目前不能使用「三板斧」！\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #             return notify_fail("你的内功火候不够，难以施展「三板斧」！\n");
  # 
  #         if ((int)me->query_skill("hammer", 1) < 180)
  #             return notify_fail("你的棍法修为不够，不会使用「三板斧」！\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #             return notify_fail("你的真气不足！\n");
  # 
  #         if (! living(target))
  #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         // 第一斧劈脑袋
  #         ap = me->query_skill("hammer") + me->query("str") * 2;
  #         dp = target->query_skill("force");
  #         damage = me->query_skill("leiting-fu", 1);
  #         damage += (me->query_str() - zhuan * 20) * 2;
  #         count = me->query_str() - zhuan * 20;
  # 
  #         msg = "\n" HIW "$N" HIW "喝道：劈脑袋！\n" NOR;
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
  #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
  #                                            "招击个正中。\n" NOR);
  #                 me->add("neili", -80);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #                 me->add("neili", -40);
  #         }
  # 
  #         // 第二斧鬼剔牙
  #         ap += me->query("dex") * 3;
  #         dp = target->query_skill("parry");
  #         damage += (me->query_dex() - zhuan * 20) * 3;
  #         count += me->query("dex") - zhuan * 20;
  #         msg += "\n" YEL "$N" YEL "喝道：鬼剔牙！\n" NOR;
  #         if (ap / 2 + random(ap * 4 / 5) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
  #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
  #                                            "招击个正中。\n" NOR);
  #                 me->add("neili", -110);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #                 me->add("neili", -55);
  #         }
  # 
  #         // 第三斧掏耳朵
  #         ap += me->query("con") * 5;
  #         dp = target->query_skill("dodge");
  #         damage += (me->query_con() - zhuan * 20) * 5;
  #         count += me->query("con") - zhuan * 20;
  #         msg += "\n" HIM "$N" HIM "喝道：掏耳朵！\n" NOR;
  #         if (ap / 3 + random(ap * 3 / 5) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
  #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
  #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
  #                                            "招击个正中。\n" NOR);
  #                 me->add("neili", -140);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
  #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
  #                 me->add("neili", -70);
  #         }
  # 
  #         me->start_busy(3 + random(3));
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
