defmodule Kantele.Combat.Skills.Performs.HanbingZhang.Han do
  @moduledoc """
  perform「极天寒掌」（source hanbing-zhang/han.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：已学此招 → 目标在战斗中 → 空手（主/副兵器皆无）→
  寒冰掌>=160 → 准备寒冰掌 → 内功>=180 → 真气>=500 → 目标存活。
  起手广播后按 `ap/2 + random(ap) > 目标 parry`（`ap = strike`）判定：
  命中则伤 `寒冰掌 + random(寒冰掌)`、qi 上限伤 60%，攻击方忙乱 3、扣 220 真气；
  失手则攻击方忙乱 4、扣 120 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., UNARMED_ATTACK, damage, 60, 文案)` 折算为
    目标侧 `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*60/100)`；
  - `.c` 的分支费用/忙乱依赖目标属性，故由目标侧 `Performs.feedback/3` 回执；
  - `.c` 的 `message_sort` 折算为房间广播；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
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

  @perform_id "hanbing-zhang/han"
  @move_name "「极天寒掌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "strike")
    lvl = Stats.skill(stats, "hanbing-zhang")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_level(stats),
         :ok <- check_prepared(stats),
         :ok <- check_force(stats),
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

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_empty_handed(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("hanbing-zhang", 1) < 160)
  defp check_level(stats) do
    if Stats.skill(stats, "hanbing-zhang") < 160 do
      {:error, "你寒冰掌不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "hanbing-zhang")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if is_binary(prepared) and prepared |> String.split("/") |> hd() == "hanbing-zhang" do
      :ok
    else
      {:error, "你没有准备寒冰掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 180)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500)
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
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
    # LPC: msg = HIY "\n$N" HIY "运转真气，将内力注于掌上，施出"
    #            "绝招「" HIW "极天寒掌" HIY "」，双掌猛然拍向$n"
    #            HIY "，掌风阴寒无比，透出阵阵寒气，犹如置身冰天"
    #            "雪地中一般，令人不寒而栗。\n" NOR;
    Broadcast.publish(
      conn,
      "\n$N运转真气，将内力注于掌上，施出绝招#{@move_name}，双掌猛然拍向$n，掌风阴寒无比，透出阵阵寒气，犹如置身冰天雪地中一般，令人不寒而栗。\n",
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
    skill = Map.get(data, :skill, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp) { damage = hanbing-zhang + random(hanbing-zhang);
    #            do_damage(me, target, UNARMED_ATTACK, damage, 60, 文案);
    #            me->start_busy(3); me->add("neili", -220); }
    #      else { me->start_busy(4); me->add("neili", -120); }
    if div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "parry") do
      damage = skill + Engine.rand(rng, max(skill, 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 60, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 220, 3)

      conn
      |> Broadcast.publish(
        "但见$N双掌拍来，掌风作响，寒气逼人。$n顿觉心惊胆战，毫无招架之力，微迟疑间$N这掌已正中$n胸口，顿将$p震退数步。\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 120, 4)

      Broadcast.publish(
        conn,
        "$n见$N这掌拍来，内力充盈，气势凌人，只得奋力向后一纵，才躲过这一掌。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HAN "「" HIW "极天寒掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/hanbing-zhang/han"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("hanbing-zhang", 1) < 160)
  #                 return notify_fail("你寒冰掌不够娴熟，难以施展" HAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "hanbing-zhang")
  #                 return notify_fail("你没有准备寒冰掌，难以施展" HAN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" HAN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不够，难以施展" HAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIY "\n$N" HIY "运转真气，将内力注于掌上，施出"
  #               "绝招「" HIW "极天寒掌" HIY "」，双掌猛然拍向$n" 
  #               HIY "，掌风阴寒无比，透出阵阵寒气，犹如置身冰天"
  #               "雪地中一般，令人不寒而栗。\n" NOR;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("hanbing-zhang", 1);
  #                 damage += random(damage);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "但见$N" HIR "双掌拍来，掌风作响，"
  #                                            "寒气逼人。$n" HIR "顿觉心惊胆战，"
  #                                            "毫无招架之力，微迟疑间$N" HIR "这掌"
  #                                            "已正中$n" HIR "胸口，顿将$p震退数步。"
  #                                            " \n" NOR);
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -220);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "这掌拍来，内力"
  #                        "充盈，气势凌人，只得奋力向后一纵，才躲"
  #                        "过这一掌。\n" NOR;
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -120);
  #         }
  #         message_sort(msg, me, target);
  #         return 1;
  # }
end
