defmodule Kantele.Combat.Skills.Performs.SadStrike.Tuo do
  @moduledoc """
  perform「拖泥带水」（source sad-strike/tuo.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "sad-strike/tuo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "sad-strike")
    ap = (Stats.skill(stats, "unarmed") + Stats.skill(stats, "force"))
    damage = (ap + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "force") < 360 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sad-strike") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    Performs.feedback(attacker, 400, 1)
    result = Messages.interpolate("$N心下万念俱灰，凄然间回想到自己的妻子couple/name，心中暗道：“别了！你自己保重。”当下失魂落魄，随手一招，恰好使出了黯然销魂掌中的「拖泥带水」。
只听$n一声闷哼，“噗”的一声，这一掌正好击在$p肩头。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(2));"], "level_gates": [{"force", "360"}, {"sad-strike", "180"}], "prepared_gates": [{"unarmed", "sad-strike"}], "remote_damage": true, "resource_gates": [{"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // tuo.c
  # // 杨过决战金轮法王时所施展的决定胜负
  # // 的一招。
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TUO "「" HIM "拖泥带水" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         int effqi, maxqi;
  #         string couple;
  # 
  #         if (userp(me) && ! me->query("can_perform/sad-strike/tuo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TUO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query("static/marry") > 1)
  #                 return notify_fail("你感情早已不纯，哪里还能领略到那种黯然销魂的感觉？\n");
  # 
  #         if ((int)me->query_skill("force") < 360)
  #                 return notify_fail("你的内功火候不够，使不出" TUO "。\n");
  # 
  #         if ((int)me->query_skill("sad-strike", 1) < 180)
  #                 return notify_fail("你的黯然销魂掌不够熟练，不会使用" TUO "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法使用" TUO "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "sad-strike")
  #                 return notify_fail("你没有准备黯然销魂掌，无法使用" TUO "。\n");
  # 
  #         if (! stringp(couple = me->query("couple/id")))
  #                 return notify_fail("你没有妻子，体会不到这种万念俱灰的感觉。\n");
  # 
  #         if (time() - me->query_temp("last_perform/sad-strike/tuo") < 60)
  #                 return notify_fail("你刚刚施展完" TUO "，现在心情没有那么郁闷了。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         effqi = me->query("eff_qi");
  #         maxqi = me->query("max_qi");
  # 
  #         ap = me->query_skill("unarmed") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  #         me->start_busy(2 + random(2));
  # 
  #         if (random(5) == 1 && me->query("max_neili") > 5000)
  #         {
  #                 msg = HIR "\n$N" HIR "心下万念俱灰，凄然间回想到自己的妻子" HIW
  #                       + me->query("couple/name") + HIR "，" HIR "心中暗道：“别了！"
  #                       "你自己保重。”当下失魂落魄，随手一招，恰好使出了黯"
  #                       "然销魂掌中的「拖泥带水」。\n" NOR;
  #                 ap += ap * 10 / 100;
  #         } else
  #         {
  #                 msg = HIM "\n只见$N" HIM "没精打采的挥袖卷出，面无表情，随意拍出一掌，正是"
  #                       "黯然销魂掌中的「拖泥带水」。\n"NOR;
  #         }
  #         if (ap * 3 / 5 + random(ap) > dp)
  #         { 
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -400);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 120,
  #                                            HIR "只听$n" HIR "一声闷哼，“噗”的一"
  #                                            "声，这一掌正好击在$p" HIR "肩头。 "
  #                                            NOR);
  #                 me->set_temp("last_perform/sad-strike/tuo", time());
  #         } else
  #         {
  #                 me->add("neili", -200);
  #                 msg += HIC "可是$p" HIC "小心应付、奋力招架，挡开了这一招。\n"
  #                        NOR;
  #         }
  #         message_sort(msg, me, target);
  #         return 1;
  # }
end
