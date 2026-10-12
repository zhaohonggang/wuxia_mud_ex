defmodule Kantele.Combat.Skills.Performs.DamoJian.Shang do
  @moduledoc """
  perform「达摩伤神剑」（source damo-jian/shang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持剑（`skill_type == "sword"`）→
  达摩剑法>=200 → 激发 sword 为达摩剑法 → 内力上限>=2000 → 真气>=300 → 目标存活。
  命中判定 `ap/2 + random(ap)`（`ap = sword + force`）对目标 `force * 2`：命中则
  `damage = ap/3 + random(ap/3)`、按 30% 计 qi 伤，额外 `damage/2` 精伤（1/4 创伤），
  并给目标挂 `damo_shangshen` 毒；攻击方扣 200 真气并忙乱 2。未命中扣 100 真气并忙乱 4。

  差异（TODO(migrate)）：
  - `do_damage(..., WEAPON_ATTACK, damage, 30, (: final, me, target, damage :))`
    折算为命中分支内的 `Vitals.damage(:qi, …)` / `Vitals.wound(:qi, div(damage * 30, 100))`，
    `final` 里的 `receive_damage("jing", damage/2)` / `receive_wound("jing", damage/4)`
    折算为 `Vitals.damage(:jing, …)` / `Vitals.wound(:jing, …)`；
  - `target->affect_by("damo_shangshen", …)` 折算为 `ConditionEvent.apply_poison/2`
    （补 `"name"` 供显示；`.c` 未给中文名）；
  - `.c` 文案 `"…将手中" + weapon->name() + "轻轻一振…"` 在 E 侧用 `<>` 拆成两段
    字面量，保持 C 侧两条消息的粒度（不得写成单段插值字符串）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "damo-jian/shang"
  @move_name "「达摩伤神剑」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "damo-jian")
    # LPC: ap = me->query_skill("sword") + me->query_skill("force");
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
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
          level: lvl,
          skill: lvl,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon)
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "damo-jian") < 200 do
      {:error, "你达摩剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "damo-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "damo-jian" do
      :ok
    else
      {:error, "你没有激发达摩剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
      vitals.neili < 300 -> {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
      true -> :ok
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

  defp apply_effect(conn, character, target, weapon) do
    # LPC: msg = HIG "$N" HIG "将手中" + weapon->name() +
    #            HIG "轻轻一振，剑脊叮叮作响，无形剑气直指$n" HIG "气海要穴。\n" NOR;
    # 命中/伤害/中毒在目标侧结算（dp 需目标 force）。
    conn
    |> Broadcast.publish(
      "$N将手中" <> Map.get(weapon, :name) <> "轻轻一振，剑脊叮叮作响，无形剑气直指$n气海要穴。\n",
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
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") * 2;
    dp = Stats.skill(stats, "force") * 2

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 3 + random(ap /3);
      damage = div(ap, 3) + Engine.rand(rng, div(ap, 3))

      # LPC: target->affect_by("damo_shangshen", ([ "level" : lvl + random(lvl),
      #        "id" : me->query("id"), "duration" : 5 + random(lvl / 20) ]));
      poison_level = lvl + Engine.rand(rng, lvl)
      poison_duration = 5 + Engine.rand(rng, div(lvl, 20))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "达摩伤神"
        })

      # LPC: do_damage(..., WEAPON_ATTACK, damage, 30, ...) → qi 伤 + 30% 创伤；
      #      final() 追加 receive_damage("jing", damage / 2) + receive_wound("jing", damage / 4)
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))
        |> Vitals.damage(:jing, div(damage, 2))
        |> Vitals.wound(:jing, div(damage, 4))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(2); me->add("neili", -200);
      Performs.feedback(attacker, 200, 2)

      # LPC final(): return HIR "结果$n" HIR "只觉气海穴上一痛，眼前一团" "黑，阵阵晕眩，难以继续战斗。\n" NOR;
      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$n只觉气海穴上一痛，眼前一团黑，阵阵晕眩，难以继续战斗。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -100);
      Performs.feedback(attacker, 100, 4)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$n内力深厚，使得$P这一招没有起到任何作用。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHANG "「" HIG "达摩伤神剑" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #     int damage;
  # 
  #     if (userp(me) && ! me->query("can_perform/damo-jian/shang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHANG "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" SHANG "。\n");
  # 
  #     if ((int)me->query_skill("damo-jian", 1) < 200)
  #                 return notify_fail("你达摩剑法不够娴熟，难以施展" SHANG "。\n");
  # 
  #     if (me->query_skill_mapped("sword") != "damo-jian")
  #                 return notify_fail("你没有激发达摩剑法，难以施展" SHANG "。\n");
  # 
  #     if ((int)me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为不够，难以施展" SHANG "。\n");
  # 
  #     if (me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" SHANG "。\n");
  # 
  #     if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "将手中" + weapon->name() +
  #               HIG "轻轻一振，剑脊叮叮作响，无形剑气直指$n"
  #               HIG "气海要穴。\n" NOR;
  # 
  #         ap = me->query_skill("sword") + me->query_skill("force");
  #         dp = target->query_skill("force") * 2;
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 3 + random(ap /3);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
  #                                            (: final, me, target, damage :));
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #     } else
  #         {
  #         msg += CYN "可是$n" CYN "内力深厚，使得$P"
  #                        CYN "这一招没有起到任何作用。\n" NOR;
  #         me->start_busy(4);
  #                 me->add("neili", -100);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int lvl = me->query_skill("damo-jian", 1);
  # 
  #         target->affect_by("damo_shangshen",
  #                 ([ "level"    : lvl + random(lvl),
  #                    "id"       : me->query("id"),
  #                    "duration" : 5 + random(lvl / 20) ]));
  # 
  #         target->receive_damage("jing", damage / 2, me);
  #         target->receive_wound("jing", damage / 4, me);
  # 
  #         return HIR "结果$n" HIR "只觉气海穴上一痛，眼前一团"
  #                "黑，阵阵晕眩，难以继续战斗。\n" NOR;
  # }
end
