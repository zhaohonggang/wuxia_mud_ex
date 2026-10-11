defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Tao do
  @moduledoc """
  perform「碧焰滔天」（source chousui-zhang/tao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "chousui-zhang/tao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chousui-zhang")
    damage = (1500 + Engine.rand(rng, (lvl * 3)))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "chousui-zhang") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "huagong-dafa") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "poison") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | max_neili: vitals.max_neili - 50}
    vitals = %{vitals | neili: 0}
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
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :qi, (damage * 2))
        vitals = Vitals.damage(vitals, :jing, div(damage, 2))
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("只见$N双目血红，头发散乱，猛地仰天发出一声悲啸。

$N把心一横，在自己舌尖狠命一咬，将毕生功力尽数喷出，顿时只见空气中血雾弥漫，腥臭无比，随即又
听$N骨骼“噼里啪啦”一阵爆响，双臂顺着喷出的血柱一推，刹那间一座丈来高的奇毒火墙拔地而起，带
着排山倒海之势向$n涌去！
$N一声惨笑，长叹一声，眼前一黑，倒在了地上。

$n见滔天热浪扑面涌来，只觉眼前一片通红，已被卷入火浪，毒焰席卷全身，连骨头都要烤焦一般。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"max_neili", "-50"}], "affect_by": ["fire_poison"], "assign_refs": [{"ap", "poison"}, {"lvl", "chousui-zhang"}], "busy_lines": ["me->start_busy(4 + random(4));", "if (! target->is_busy())", "target->start_busy(5);", "if (! target->is_busy())", "target->start_busy(10);"], "level_gates": [{"chousui-zhang", "220"}, {"huagong-dafa", "220"}, {"poison", "250"}], "prepared_gates": [{"strike", "chousui-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "3000"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define TAO "「" HIG "碧焰滔天" NOR "」"
  # 
  # int unconcious_me(object me);
  # 
  # int perform(object me, object target)
  # {
  #         object du;
  #         int damage;
  #         int ap;
  #         string msg;
  #         int lvl;
  # 
  #         if (userp(me) && ! me->query("can_perform/chousui-zhang/tao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能对战斗中的对手施展" TAO "。\n");
  # 
  #         if ((int)me->query_skill("chousui-zhang", 1) < 220)
  #                 return notify_fail("你的抽髓掌火候不够。\n");
  # 
  #         if ((int)me->query_skill("poison", 1) < 250)
  #                 return notify_fail("你的基本毒技火候不够。\n");
  # 
  #         if ((int)me->query_skill("huagong-dafa", 1) < 220)
  #                 return notify_fail("你的化功大法火候不够。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，无法用内力施展" TAO "。\n");
  # 
  #         if ((int)me->query("neili") < 3000)
  #                 return notify_fail("你现在内息不足，无法用内力施展" TAO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chousui-zhang")
  #                 return notify_fail("你还没有准备抽髓掌，无法施展" TAO "。\n");
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你必须将全身功力尽数提起才能施展" TAO "。\n");
  # 
  #         if (! objectp(du = me->query_temp("handing")) && userp(me))
  #                 return notify_fail("你首先要拿着(hand)一些毒药作为引子。\n");
  # 
  #         if (objectp(du) && ! mapp(du->query("poison")))
  #                 return notify_fail(du->name() + "又不是毒药，无法运射出毒焰？\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "只见$N" HIR "双目血红，头发散乱，猛地仰天发出一声悲啸。\n\n"
  #               "$N" HIR "把心一横，在自己舌尖狠命一咬，将毕生功力尽"
  #               "数喷出，顿时只见空气中血雾弥漫，腥臭无比，随即又\n"
  #               "听$N" HIR "骨骼“噼里啪啦”一阵爆响，双臂顺着喷出的"
  #               "血柱一推，刹那间一座丈来高的奇毒火墙拔地而起，带\n"
  #               "着排山倒海之势向$n" HIR "涌去！\n" NOR;
  #         me->start_busy(4 + random(4));
  #         me->set("neili", 0);
  #         me->add("max_neili", -50);
  # 
  #         lvl = me->query_skill("chousui-zhang", 1);
  #         damage = 1500 + random(lvl * 3);
  # 
  #         if (me->query("max_neili") + random(me->query("max_neili")) <
  #             target->query("max_neili") * 18 / 10)
  #         {
  #                 msg += WHT "$n" WHT "见状连忙提运内力，双臂猛"
  #                        "的推出，掌风澎湃，强大的气流顿时将火浪"
  #                        "刮得倒转，竟然掉头向$N" WHT "扑去。\n\n" NOR;
  #                 msg += HIR "$N" HIR "一声惨笑，长叹一声，眼前一黑，倒在了地上。\n\n" NOR;
  #                 me->add("max_neili", -random(50));
  # 
  #                 remove_call_out("unconcious_me");
  #                 call_out("unconcious_me", 1, me);
  # 
  #         } else
  #         {
  #                 ap = me->query_skill("poison", 1) / 2 +
  #                      me->query_skill("force, 1");
  #                      //me->query_skill("force");
  #                 if (ap + random(ap) < target->query_skill("dodge"))
  #                 {
  #                         msg += CYN "$n" CYN "见势不妙，急忙腾挪身形，避开了$N" CYN "的攻击。\n" NOR;
  #                         me->add("max_neili", -random(50));
  #                         if (! target->is_busy())
  #                                 target->start_busy(5);
  #                 } else
  #                 {
  #                         msg += HIR "$n" HIR "见滔天热浪扑面涌来，只觉眼前一片通红，"
  #                                "已被卷入火浪，毒焰席卷全身，连骨头都要烤焦一般。\n" NOR;
  #                         me->add("max_neili", -random(50));
  #                         target->affect_by("fire_poison",
  #                                        ([ "level" : me->query("jiali") * 3 + random(me->query("jiali") * 2),
  #                                           "id"    : me->query("id"),
  #                                           "duration" : lvl / 20 + random(lvl) ]));
  #                         target->receive_damage("qi", damage * 2);
  #                         target->receive_damage("jing", damage / 2);
  #                         if (! target->is_busy())
  #                                 target->start_busy(10);
  #                 }
  #         }
  # 
  #         if (objectp(du)) destruct(du);
  #         message_vision(msg, me, target);
  #         me->want_kill(target);
  #         if (! target->is_killing(me)) target->kill_ob(me);
  # 
  #         return 1;
  # }
  # 
  # int unconcious_me(object me)
  # {
  #         if (! objectp(me))
  #               return 1;
  # 
  #         if (living(me))
  #               me->unconcious();
  # 
  #         return 1;
  # }
end
