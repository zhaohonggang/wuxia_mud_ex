defmodule Kantele.Combat.Skills.Performs.CuixinZhang.Cui do
  @moduledoc """
  perform「夺命催心」（source cuixin-zhang/cui.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "cuixin-zhang/cui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "cuixin-zhang")
    ap = (Stats.skill(stats, "strike") + Stats.skill(stats, "force"))
    count = div(lvl, 8)
    dp = 1
    damage = (div(ap, 2) + Engine.rand(rng, ap))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 260}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 260, 3)
    result = Messages.interpolate("$N聚气于掌，仰天一声狂啸，刹那间双掌交错，一招「夺命催心」带着阴毒内劲直贯$n！
只听$n惨叫一声，只感两耳轰鸣，目不视物，软软瘫倒。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-260"}], "affect_by": ["cuixin_zhang"], "apply_adds": ["parry"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}, {"lvl", "cuixin-zhang"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "120"}], "remote_damage": true, "resource_gates": [{"neili", "500"}], "temp_set": ["cuixin"], "var_gates": [{"dp", "1"}, {"lvl", "120"}]}

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
