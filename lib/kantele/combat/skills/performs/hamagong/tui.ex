defmodule Kantele.Combat.Skills.Performs.Hamagong.Tui do
  @moduledoc """
  exert「tui」（source hamagong/tui.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：目标在战斗中 → 蛤蟆功>=240 → 内力上限>=4000 →
  真气>=1000 → 目标存活。
  起手广播「…平推而出…奔向$n」；以 `force*15 + 内力上限`（攻击方）对
  `force*15 + 内力上限 + 一阳指*20`（目标，至少 1）判定三分支：
  - `ap/2 + random(ap) > dp` 且 `ap > dp`：伤 `(ap-dp)/10 + random(ap/10)`、
    上限伤 60%，攻击方扣 300 真气、忙乱 2；
  - 目标会一阳指：攻击方忙乱 2、扣 200 真气；
  - 其余：攻击方扣 200 真气、忙乱 3，目标忙乱 1、扣 200 真气（不足则清零）。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., REMOTE_ATTACK, damage, 60, 文案)` 折算为
    目标侧 `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*60/100)`；
  - `.c` 的分支费用/忙乱依赖目标属性，故由目标侧 `Performs.feedback/3` 回执；
  - `target->query_skill("yiyang-zhi", 1)` 的门槛在目标侧判定；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "hamagong/tui"
  @move_name "「推天式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("force") * 15 + me->query("max_neili");
    ap = Stats.skill(stats, "force") * 15 + character.meta.vitals.max_neili

    with {:ok, target} <- target(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id, ap: ap, rng: rng}
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #        return notify_fail("蛤蟆功「推天式」只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "蛤蟆功#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: skill = me->query_skill("hamagong", 1); if (skill < 240)
  #        return notify_fail("你的蛤蟆功修为不够精深，不能使用「推天式」！\n");
  defp check_levels(stats) do
    if Stats.skill(stats, "hamagong") < 240 do
      {:error, "你的蛤蟆功修为不够精深，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 4000)
  #        return notify_fail("你的内力修为不够深厚，无法施展「推天式」！\n");
  #      if (me->query("neili") < 1000)
  #        return notify_fail("你的真气不够，无法运用「推天式」！\n");
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "你的内力修为不够深厚，无法施展#{@move_name}！\n"}
      vitals.neili < 1000 -> {:error, "你的真气不够，无法运用#{@move_name}！\n"}
      true -> :ok
    end
  end

  # LPC: if (! living(target))
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "蹲在地上，“嗝”的一声大叫，双手弯"
    #            "与肩齐，平推而出，一股极大的力道如同"
    #            "排山倒海一般奔向$n" HIY "。\n" NOR;
    Broadcast.publish(
      conn,
      "$N蹲在地上，“嗝”的一声大叫，双手弯与肩齐，平推而出，一股极大的力道如同排山倒海一般奔向$n。\n",
      n1: character.name,
      n2: target.name
    )
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
    stats = character.meta.stats
    vitals = character.meta.vitals
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") * 15 + target->query("max_neili") +
    #            target->query_skill("yiyang-zhi", 1) * 20;
    #      if (dp < 1) dp = 1;
    dp =
      max(
        Stats.skill(stats, "force") * 15 + vitals.max_neili +
          Stats.skill(stats, "yiyang-zhi") * 20,
        1
      )

    cond do
      div(ap, 2) + Engine.rand(rng, ap) > dp and ap > dp ->
        # LPC: me->add("neili", -300); me->start_busy(2);
        #      damage = (ap - dp) / 10 + random(ap / 10);
        #      msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 60, 文案);
        #      do_damage: receive_damage("qi", damage); receive_wound("qi", damage*60/100);
        damage = div(ap - dp, 10) + Engine.rand(rng, max(div(ap, 10), 1))

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 60, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 300, 2)

        conn
        |> Broadcast.publish(
          "$n奋力低档，但是$P的来势何等浩大，$p登时觉得气血不畅，“哇”的吐出了一口鲜血。\n",
          bindings
        )
        |> put_character(character)

      Stats.skill(stats, "yiyang-zhi") > 0 ->
        # LPC: me->start_busy(2); me->add("neili", -200);
        Performs.feedback(attacker, 200, 2)

        Broadcast.publish(
          conn,
          "然而$p哈哈一笑，随手一指刺出，正是一阳指的精妙招数，轻易的化解了$P的攻势。\n",
          bindings
        )

      true ->
        # LPC: me->add("neili", -200); me->start_busy(3);
        #      target->start_busy(1);
        #      if (target->query("neili") > 200) target->add("neili", -200);
        #      else target->set("neili", 0);
        Performs.feedback(attacker, 200, 3)

        neili = if vitals.neili > 200, do: vitals.neili - 200, else: 0

        combat = Combat.start_busy(character.meta.combat, 1)
        vitals = %{vitals | neili: neili}
        character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

        conn
        |> Broadcast.publish(
          "可是$n将内力运到双臂上，接下了$P这一推之式，只听“蓬”的一声，震得四周尘土飞扬。\n",
          bindings
        )
        |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // tui.c 推
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #         string msg;
  #         int skill, ap, dp, damage;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("蛤蟆功「推天式」只能对战斗中的对手使用。\n");
  # 
  #         skill = me->query_skill("hamagong", 1);
  # 
  #         if (skill < 240)
  #                 return notify_fail("你的蛤蟆功修为不够精深，不能使用「推天式」！\n");
  # 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不够深厚，无法施展「推天式」！\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你的真气不够，无法运用「推天式」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "蹲在地上，“嗝”的一声大叫，双手弯"
  #               "与肩齐，平推而出，一股极大的力道如同"
  #               "排山倒海一般奔向$n" HIY "。\n" NOR;
  # 
  #         ap = me->query_skill("force") * 15 + me->query("max_neili");
  #         dp = target->query_skill("force") * 15 + target->query("max_neili") +
  #              target->query_skill("yiyang-zhi", 1) * 20;
  #         if (dp < 1) dp = 1;
  #         if ((ap / 2 + random(ap) > dp)&&(ap>dp))
  #         {
  #                 me->add("neili", -300);
  #                 me->start_busy(2);
  #                 damage = (ap - dp) / 10 + random(ap / 10);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 60,
  #                                            HIR "$n" HIR "奋力低档，但是$P" HIR "的来势何"
  #                                            "等浩大，$p" HIR "登时觉得气血不畅，“哇”的"
  #                                            "吐出了一口鲜血。\n" NOR);
  #         } else
  #         if (target->query_skill("yiyang-zhi", 1))
  #         {
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #                 msg += HIG "然而$p" HIG "哈哈一笑，随手一指刺出，正是一"
  #                        "阳指的精妙招数，轻易的化解了$P" HIG "的攻势。\n" NOR;
  #         } else
  #         {
  #                 me->add("neili",-200);
  #                 msg += CYN "可是$n" CYN "将内力运到双臂上，接下了$P"
  #                        CYN "这一推之式，只听“蓬”的一声，震得四周"
  #                        "尘土飞扬。\n" NOR;
  #                 me->start_busy(3);
  #                 target->start_busy(1);
  #                 if (target->query("neili") > 200)
  #                         target->add("neili", -200);
  #                 else
  #                         target->set("neili", 0);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
