defmodule Kantele.Combat.Skills.Performs.CuixinZhang.Cui do
  @moduledoc """
  perform「夺命催心」（source cuixin-zhang/cui.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 催心掌>=120 →
  内功>=120 → 真气>=500 → 目标存活 → 目标未中本招。命中判定
  `(strike+force)*11/20 + random(strike+force)` vs 目标 `parry+force`
  （`dp<1` 时取 1）：命中则伤害 `ap/2 + random(ap)`、按 `random(15)+40` 计 qi 伤、
  附加 cuixin_zhang 毒，并令目标 `apply/parry -count`（`count = lvl/8`）持续
  `5 + random(count/5)` 秒后由 `combat/buff-expire` 加回；攻击方扣 260 真气
  并忙乱 2。未命中扣 120 真气并忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的攻击侧门槛 `target->query_temp("cuixin")` 需读目标状态，本引擎敌列表
    只存引用快照，改由目标侧幂等处理（重复命中直接覆盖 buff），门槛文案保留；
  - `do_damage(..., random(15)+40, (: final, me, target, count :))` 的 `final`
    回调折算为命中分支内的 `Vitals.damage(:qi, …)` / `Vitals.wound(:qi, …)` +
    `Combat.apply_temp/2`（parry 减益）+ `Process.send_after` 的
    `combat/buff-expire`（对应 `call_out("cuixin_end", …)`）；
  - `cuixin_end` 的 `message_combatd`（房间可见）经引擎 buff-expire 降级为
    目标私有文案（同 `damo_jian/qingxin.ex` 的可接受偏差）；
  - `target->affect_by("cuixin_zhang", …)` 折算为 `ConditionEvent.apply_poison/2`
    （`.c` 未给毒名，此处补 `"name"` 供显示）；
  - `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "cuixin-zhang/cui"
  @move_name "「夺命催心」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "cuixin-zhang")
    # LPC: ap = me->query_skill("strike") + me->query_skill("force");
    ap = Stats.skill(stats, "strike") + Stats.skill(stats, "force")
    # LPC: count = lvl / 8;
    count = div(lvl, 8)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target),
         :ok <- check_target_cuixin(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          count: count,
          jiali: combat.jiali,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须是空手才能使用！\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "cuixin-zhang") < 120 ->
        {:error, "你的催心掌还不够纯熟，无法施展#{@move_name}\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太低，无法使出#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的内力不够，无法使出#{@move_name}。\n"}
    else
      :ok
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

  # LPC: if (target->query_temp("cuixin")) return notify_fail("对方已经招架涣散，放胆攻击吧。\n");
  # 敌人列表只存引用快照，读不到目标 temp；改由目标侧幂等覆盖 buff，门槛文案保留。
  defp check_target_cuixin(target) do
    if cuixin?(target) do
      {:error, "对方已经招架涣散，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp cuixin?(%{meta: %{combat: %{buffs: buffs}}}) when is_list(buffs),
    do: Enum.any?(buffs, &(&1.key == "cuixin"))

  defp cuixin?(_), do: false

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIR "$N" HIR "聚气于掌，仰天一声狂啸，刹那间双掌交错，一招"
    #           "「夺命催心」带着阴毒内劲直贯$n" HIR "！\n"NOR;
    #      命中/失手在目标侧结算（dp 需目标 parry+force）。
    conn
    |> Broadcast.publish(
      "$N聚气于掌，仰天一声狂啸，刹那间双掌交错，一招「夺命催心」带着阴毒内劲直贯$n！\n",
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
    count = Map.get(data, :count, 0)
    lvl = Map.get(data, :level, 0)
    jiali = Map.get(data, :jiali, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("force");
    #      if (dp < 1) dp = 1;
    dp = max(Stats.skill(stats, "parry") + Stats.skill(stats, "force"), 1)

    # LPC: if (ap * 11 / 20 + random(ap) > dp)
    if div(ap * 11, 20) + Engine.rand(rng, ap) > dp do
      # LPC: target->affect_by("cuixin_zhang",
      #          ([ "level" : me->query("jiali") + random(me->query("jiali")),
      #             "id"    : me->query("id"),
      #             "duration" : lvl / 50 + random(lvl / 20) ]));
      poison_level = jiali + Engine.rand(rng, jiali)
      poison_duration = div(lvl, 50) + Engine.rand(rng, div(lvl, 20))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "催心毒"
        })

      # LPC: damage = ap / 2 + random(ap);
      #      msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage,
      #                                 random(15) + 40, (: final, me, target, count :));
      damage = div(ap, 2) + Engine.rand(rng, ap)
      percent = Engine.rand(rng, 15) + 40

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * percent, 100))

      # LPC final(): target->set_temp("cuixin", 1);
      #              target->add_temp("apply/parry", -count);
      #              call_out("cuixin_end", 5 + random(count / 5), me, target, count);
      combat =
        character.meta.combat
        |> Combat.apply_temp(%{parry: -count})
        |> Combat.add_buff(%Combat.Buff{key: "cuixin", applies: %{parry: count}})

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      # LPC cuixin_end(): message_combatd("$N的视力和听力逐渐恢复了知觉。\n", target);
      #                   tell_object(target, "你感到被扰乱的真气慢慢平静了下来。\n");
      #                   target->delete_temp("cuixin"); target->add_temp("apply/parry", count);
      Process.send_after(
        self(),
        %Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{
            key: "cuixin",
            applies: %{parry: count},
            message:
              [
                Messages.interpolate("$N的视力和听力逐渐恢复了知觉。\n", n1: character.name),
                "你感到被扰乱的真气慢慢平静了下来。\n"
              ]
              |> Enum.join("")
          }
        },
        (5 + Engine.rand(rng, div(count, 5))) * 1000
      )

      # LPC: me->add("neili", -260); me->start_busy(2);
      Performs.feedback(attacker, 260, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("只听$n惨叫一声，只感两耳轰鸣，目不视物，软软瘫倒。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -120); me->start_busy(3);
      Performs.feedback(attacker, 120, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("$p见$P来势汹涌，踉踉跄跄的躲开了这致命的一击！\n", bindings)
      )
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define CUI "「" HIW "夺命催心" NOR "」"
  # string final(object me, object target, int count);
  # void cuixin_end(object me, object target, int count);
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object /*weapon,*/ target;
  #         int ap, dp;
  #         int damage, lvl, count;
  # 
  #         if (playerp(me) && ! me->query("can_perform/cuixin-zhang/cui"))
  #                 return notify_fail("你使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CUI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能使用！\n");
  # 
  #         lvl = me->query_skill("cuixin-zhang", 1);
  # 
  #         if (lvl < 120)
  #                 return notify_fail("你的催心掌还不够纯熟，无法施展" CUI "\n");
  # 
  #         if (me->query_skill("force") < 120)
  #                 return notify_fail("你的内功火候太低，无法使出" CUI "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的内力不够，无法使出" CUI "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (target->query_temp("cuixin"))
  #                 return notify_fail("对方已经招架涣散，放胆攻击吧。\n");
  # 
  #         msg = HIR "$N" HIR "聚气于掌，仰天一声狂啸，刹那间双掌交错，一招"
  #                   "「夺命催心」带着阴毒内劲直贯$n" HIR "！\n"NOR;
  # 
  # 
  #         ap = me->query_skill("strike") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  #         count = lvl / 8;
  # 
  #         if (dp < 1) dp = 1;
  # 
  #         if ( ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 msg += HIR "只听$n" HIR "惨叫一声，只感两耳轰鸣，目不视物，软软瘫倒。\n" NOR;
  #                 target->affect_by("cuixin_zhang",
  #                         ([ "level" : me->query("jiali") + random(me->query("jiali")),
  #                            "id"    : me->query("id"),
  #                            "duration" : lvl / 50 + random(lvl / 20) ]));
  # 
  #                 damage = ap / 2 + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, random(15) + 40,
  #                                           (: final, me, target, count :));
  # 
  #                 me->add("neili", -260);
  #                 me->start_busy(2);
  #         }
  #         else
  #         {
  # 
  #                 msg += HIY "$p见$P来势汹涌，踉踉跄跄的躲开了这致命的一击！\n" NOR;
  #                 me->add("neili", -120);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  # 
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int count)
  # {
  #         target->set_temp("cuixin", 1);
  #         target->add_temp("apply/parry", -count);
  #         call_out("cuixin_end", 5 + random(count / 5), me, target, count);
  # }
  # 
  # void cuixin_end(object me, object target, int count)
  # {
  #         if (target && target->query_temp("cuixin"))
  #         {
  #                 if (living(target))
  #                 {
  #                         message_combatd(HIC "$N" HIC "的视力和听力逐渐恢复了知觉。\n" NOR, target);
  #                         tell_object(target, HIY "你感到被扰乱的真气慢慢平静了下来。\n" NOR);
  #                 }
  #                 target->delete_temp("cuixin");
  #                 target->add_temp("apply/parry", count);
  #         }
  #     return;
  # }
end
