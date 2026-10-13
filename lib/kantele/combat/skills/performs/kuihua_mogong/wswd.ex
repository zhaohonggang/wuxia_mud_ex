defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Wswd do
  @moduledoc """
  perform「无双无对」（source kuihua-mogong/wswd.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中且存活 → 持剑且激发 sword 为
  葵花魔功 → 葵花魔功>=400 → 内力上限>=7000 → 内力>=1000 → 目标存活。
  ap = 葵花魔功 + dex*20 + 武学修养；dp = 目标招架 + 目标 dex*20 + 目标武学修养。

  第一式「无双」：ap*3/5 + random(ap) < dp 则未命中（扣 300 内力、忙乱 2）；
  否则伤害 = ap + random(ap/4) - random(100)、80% 外伤（扣 500 内力、忙乱 1）。

  第二式「无对」（已学会 `kuihua-mogong/wd` 且内力足够时紧接施展）：
  ap/2 + random(ap) < dp 则未命中（再扣 300 内力、忙乱+2）；否则伤害 =
  ap + random(ap/2) - random(100)、100% 外伤（再扣 600 内力、忙乱+1）。

  差异（TODO(migrate)）：
  - LPC 的两式分处 `perform()` 与 `call_out("perform2", 0, …)`，本版合并为同一次
    `combat/perform-incoming`：是否已学「无对」与攻击方当前内力随事件数据传入
    目标侧，两式在同一次结算中按 LPC 顺序完成；
  - `perform2` 的三个 `notify_fail`（对手不在/对手不能再战/内力不够）是仅攻击方
    可见的提示，跨进程文本未建模，文案保留在目标侧分支内；
  - `check_wd()` 的 `call_out` 领悟（int + random(80) >= 100 时学会「无对」）
    未建模，领悟文案保留在攻击方；
  - `living(target)` 门槛在攻击方无 meta 可查时恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "kuihua-mogong/wswd"
  @wd_perform_id "kuihua-mogong/wd"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    ap = Stats.skill(stats, "kuihua-mogong") + stats.dex * 20 + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(combat, character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      weapon_name = Map.get(weapon, :name)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          # 命中文案含 weapon->name()（攻击方武器名），经事件数据传给目标侧
          weapon_name: weapon_name,
          # 第二式「无对」的触发条件随事件数据传入目标侧
          wd_known: Stats.perform_known?(stats, @wd_perform_id),
          attacker_neili: character.meta.vitals.neili,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "无双无对只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #          || (string)weapon->query("skill_type") != "sword"
  #          || me->query_skill_mapped("sword") != "kuihua-mogong")
  # 武器结构体字段是 :skill_type（非 LPC 的 query("skill_type")）
  defp check_weapon(combat, character) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "sword" and
         Stats.mapped(character.meta.stats, "sword") == "kuihua-mogong" do
      {:ok, weapon}
    else
      {:error, "你现在无法使用绝技。\n"}
    end
  end

  # LPC: if (me->query_skill("kuihua-mogong", 1) < 400)
  #          return notify_fail("以你目前的修为来看，还不足以运用"WS"\n");
  # （「无双」无结尾标点，与 .c 逐字一致）
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kuihua-mogong") < 400 do
      {:error, "以你目前的修为来看，还不足以运用「无双」\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 7000) / if (me->query("neili") < 1000)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 7000 -> {:error, "你的内力修为不够运用「无双无对」所需！\n"}
      vitals.neili < 1000 -> {:error, "你的内力不够运用「无双」所需！\n"}
      true -> :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIM "$N突然身形一转眨眼间使出葵花魔功的终极绝招----"WSWD"之"WS"\n"
  #               HIW "$N眼神莹然有光，似乎进入了魔境之中。\n"
  #               "$N手中" + weapon->name() + "化做无双剑影攻向$n。\n";
  # （WSWD/WS 宏展开后各段仅由颜色宏/空白分隔，合并至 weapon->name() 前为一段）
  defp apply_effect(conn, character, target, weapon_name) do
    msg =
      "$N突然身形一转眨眼间使出葵花魔功的终极绝招----「无双无对」之「无双」\n$N眼神莹然有光，似乎进入了魔境之中。\n$N手中" <>
        weapon_name <> "化做无双剑影攻向$n。\n"

    # LPC: check_wd()（未学会「无对」时 3 秒后有几率领悟，call_out 未建模，保留文案）
    _learn_msg =
      "\n你突然若有所悟，对刚才使用过的葵花魔功之「无双」式反复琢磨，\n对了，这样也可以耶！你学会了「无双无对」之「无对」式！\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
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
    ap = max(Map.get(data, :ap, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    wd_known = Map.get(data, :wd_known, false)
    attacker_neili = Map.get(data, :attacker_neili, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry",1) + target->query("dex") * 20
    #               + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + stats.dex * 20 + Stats.skill(stats, "martial-cognize")

    # 第一式「无双」
    {neili1, busy1, conn, character} =
      # LPC: if (ap * 3 / 5 + random(ap) < dp)
      if div(ap * 3, 5) + Engine.rand(rng, ap) < dp do
        conn =
          conn
          |> Broadcast.publish(
            Messages.interpolate("然而$n抵挡得法，将$N的攻势化解。\n", bindings)
          )

        {300, 2, conn, character}
      else
        # LPC: damage = ap + random(ap / 4) - random(100);
        #          do_damage(me, target, WEAPON_ATTACK, damage, 80, …);
        #          me->add("neili", -500); busy = 1;
        damage = max(ap + Engine.rand(rng, div(ap, 4)) - Engine.rand(rng, 100), 0)
        character = apply_damage(character, damage, 80)

        conn =
          conn
          |> Broadcast.publish(
            Messages.interpolate(
              "$n只觉得已经跌入了万劫魔域之中，$N手中" <> weapon_name <>
                "如同地狱中的鬼火般，从各个方位刺了过来，避无可避！\n",
              bindings
            )
          )

        {500, 1, conn, character}
      end

    # 第二式「无对」
    # LPC: if (me->query("can_perform/kuihua-mogong/wd")) call_out("perform2", 0, …)
    {neili_cost, busy, conn, character} =
      if wd_known and attacker_neili - neili1 >= 1000 do
        # LPC perform2 的入场门槛（notify_fail 仅攻击方可见，跨进程文本未建模，保留文案）
        _gone_msg = "对手已经不在这里了！\n"
        _dead_msg = "对手已经不能再战斗了。\n"
        _no_neili_msg = "你待要再出「无对」，却发现自己的内力不够了！\n"

        conn =
          conn
          |> Broadcast.publish(
            Messages.interpolate(
              "说时迟那时快，$N身形逆转使出了「无双无对」之「无对」式，刹那间天空阴云密布，\n$n的心脏几乎停止了跳动，呆呆的望着$N\n",
              bindings
            )
          )

        # LPC: if (ap / 2 + random(ap) < dp)
        if div(ap, 2) + Engine.rand(rng, ap) < dp do
          conn =
            conn
            |> Broadcast.publish(
              Messages.interpolate(
                "这时$n屏住呼吸抵挡得法，将$N的攻势一一化解。\n",
                bindings
              )
            )

          {neili1 + 300, busy1 + 2, conn, character}
        else
          # LPC: damage = ap + random(ap / 2) - random(100);
          #          do_damage(me, target, WEAPON_ATTACK, damage, 100, …);
          #          busy += 1; me->add("neili", -600);
          damage = max(ap + Engine.rand(rng, div(ap, 2)) - Engine.rand(rng, 100), 0)
          character = apply_damage(character, damage, 100)

          conn =
            conn
            |> Broadcast.publish(
              Messages.interpolate(
                "$n只觉身上如同万剑穿心一般，$N如同死神一般，势必要取$n性命！\n",
                bindings
              )
            )

          {neili1 + 600, busy1 + 1, conn, character}
        end
      else
        {neili1, busy1, conn, character}
      end

    # LPC: me->start_busy(busy)（两式忙乱累加后一次性施加）
    Performs.feedback(attacker, neili_cost, busy)

    conn
    |> put_character(character)
  end

  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WSWD "「" HIR "无"BLU"双"HIM"无"HIW"对" NOR "」"
  # #define WS "「" HIR "无"BLU"双" NOR "」"
  # #define WD "「" HIM"无"HIW"对" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #     int damage, busy;
  # 
  #     if( !target ) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/ws"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if( !target || !me->is_fighting(target) || !living(target) )
  #         return notify_fail("无双无对只能对战斗中的对手使用。\n");
  # 
  #     if( ! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "sword"
  #         || me->query_skill_mapped("sword") != "kuihua-mogong" )
  #             return  notify_fail("你现在无法使用绝技。\n");
  # 
  #     if (me->query_skill("kuihua-mogong", 1) < 400)
  #         return notify_fail("以你目前的修为来看，还不足以运用"WS"\n");
  # 
  #     if (me->query("max_neili") < 7000)
  #         return notify_fail("你的内力修为不够运用"WSWD"所需！\n");
  # 
  #     if (me->query("neili") < 1000)
  #         return notify_fail("你的内力不够运用"WS"所需！\n");
  # 
  #     if (! living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #     ap = me->query_skill("kuihua-mogong", 1) + me->query("dex") * 20 + me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("parry",1) + target->query("dex") * 20 + target->query_skill("martial-cognize", 1);
  #     msg =HIM "$N突然身形一转眨眼间使出葵花魔功的终极绝招----"NOR""WSWD""HIM"之"NOR""WS"\n"HIW"$N眼神莹然有光，似乎进入了魔境之中。\n"
  #     "$N手中" + weapon->name() + "化做无双剑影攻向$n。\n";
  # 
  #         if (ap *3/5 + random(ap) < dp)
  #         {
  #             msg += HIG "然而$n" HIG "抵挡得法，将$N" HIG
  #             "的攻势化解。\n" NOR;
  #             busy = 2;
  #             me->add("neili", -300);
  #         } else
  #         {
  #             busy = 1;
  #             me->add("neili", -500);
  #             damage = ap + random(ap * 1 / 4) - random(100);
  #             msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #               HIY "$n" BLU "只觉得已经跌入了万劫魔域之中，"HIY"$N手中"+weapon->name()+
  #               WHT "如同地狱中的鬼火般，从各个方位刺了过来，避无可避！\n" NOR);
  # 
  #         }
  #         message_vision(msg, me, target);
  #         if(me->query("can_perform/kuihua-mogong/wd")){
  #             call_out("perform2", 0, me, target, busy);
  #         }
  #         else{
  #             //没学会无对
  #             me->start_busy(busy);
  #             call_out("check_wd", 3, me);
  #         }
  # 
  #     return 1;
  # }
  # int perform2(object me, object target,int busy)
  # {       int ap, dp;
  #         string msg;
  #         int damage;
  # 
  #         if (!me || !target) return notify_fail("对手已经不在这里了！\n");
  #         if(!living(target))
  #             return notify_fail("对手已经不能再战斗了。\n");
  #         if(me->query("neili") < 1000)
  #             return notify_fail("你待要再出"WD"，却发现自己的内力不够了！\n");
  #         ap = me->query_skill("kuihua-mogong", 1) + me->query("dex") * 20 + me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry",1) + target->query("dex") * 20 + target->query_skill("martial-cognize", 1);
  # 
  #         msg =HIM "说时迟那时快，$N身形逆转使出了"NOR""WSWD"之"WD""HIM"式，刹那间天空阴云密布，\n"NOR""HIM"$n的心脏几乎停止了跳动，呆呆的望着$N\n"NOR;
  # 
  #         if (ap / 2 + random(ap) < dp)
  #         {
  #             msg += HIG "这时$n屏住呼吸" HIG "抵挡得法，将$N" HIG"的攻势一一化解。\n" NOR;
  #               busy += 2;
  #               me->add("neili", -300);
  #         } else
  #         {
  #             busy += 1;
  #             me->add("neili",-600);
  #             damage = ap + random(ap * 1 / 2) - random(100);
  #             msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
  #               HIY "$n" BLU "只觉身上如同万剑穿心一般，"HIY"$N"
  #               WHT "如同死神一般，势必要取$n性命！\n" NOR);
  #         }
  #         me->start_busy(busy);
  #         message_vision(msg, me, target);
  #         return 1;
  # }
  # int check_wd(object me)
  # {
  #     if(me->query("int") + random(80) >= 100) {
  #         tell_object(me, HIW "\n你突然若有所悟，对刚才使用过的葵花魔功之"WS""HIW"式反复琢磨，\n对了，这样也可以耶！你学会了"WSWD""HIW"之"WD""HIW"式！\n" NOR);
  #         me->set("can_perform/kuihua-mogong/wd",1);
  #     }
  #     return 1;
  # }
end
