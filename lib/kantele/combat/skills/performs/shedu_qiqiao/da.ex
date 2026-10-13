defmodule Kantele.Combat.Skills.Performs.SheduQiqiao.Da do
  @moduledoc """
  perform「da」（source shedu-qiqiao/da.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "shedu-qiqiao/da"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shedu-qiqiao")
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = (weapon && weapon.name) || ""

    with :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          weapon_name: weapon_name,
          rng: rng
        }
      })

      apply_effect(conn, character, weapon_name, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你要打哪条蛇？\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_snake(character),
         :ok <- check_living(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "shedu-qiqiao") < 20 -> {:error, "你的蛇毒奇巧还不够娴熟，不能打蛇。\n"}
      Stats.skill(stats, "force") < 30 -> {:error, "你的内功的修为不够，不能打蛇。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "你现在的内力不够了。\n"}
      true -> :ok
    end
  end

  defp check_snake(character) do
    if snake?(character) do
      :ok
    else
      {:error, "看清楚些，那不是蛇，你瞎打什么？\n"}
    end
  end

  defp check_living(character) do
    if dead?(character) do
      {:error, "那条蛇暂时不会动弹了，你不必再打了。\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}) when dead == true, do: true
  defp dead?(_), do: false

  defp snake?(_character), do: true

  defp apply_effect(conn, character, weapon_name, target) do
    # 前置广播：依据是否有武器选择消息
    msg =
      if weapon_name != "" do
        "舞动手中的" <> weapon_name <> "，朝着" <> target.name <> "的七寸打了过去。"
      else
        "伸出双指，出指如风，迅疾无比的朝着" <> target.name <> "的七寸点了过去。"
      end

    Broadcast.publish(conn, Messages.interpolate(msg, n1: character.name))
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"lvl", "force"}, {"lvl", "shedu-qiqiao"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"force", "30"}, {"shedu-qiqiao", "20"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"lvl", "force"}, {"lvl", "shedu-qiqiao"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"force", "30"}, {"shedu-qiqiao", "20"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    do_resolve_incoming(conn, character, attacker, data)
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    target_ce = stats.combat_exp

    # LPC: lvl = (shedu-qiqiao + dodge)^3 / 10
    # if lvl/2 + random(lvl) > target_ce -> hit
    #   then: msg "结果只听“啪”的一声，正打在{target}的七寸上。"
    #   then: inner check with force lvl * 13/10 cubed
    #     if inner succeeds: "只见{target}身子轻轻晃动几下，就不再动弹了。" + unconcious
    #     else: "哪里想到{target}挨了这一击，竟然若无其事，顿时一个翻身，直扑向{attacker}！" + kill_ob
    # else: miss -> "然而{target}身子一闪，躲了过去。" + kill_ob
    # neili -50, busy 2

    lvl = Stats.skill(stats, "shedu-qiqiao") + Stats.skill(stats, "dodge")
    lvl = div(lvl * lvl * lvl, 10)

    hit = div(lvl, 2) + rng.(lvl) > target_ce

    hit_msg = "结果只听“啪”的一声，正打在" <> character.name <> "的七寸上。"

    msgs =
      if hit do
        force_lvl = Stats.skill(stats, "force")
        force_lvl = div(force_lvl * 13, 10)
        force_lvl = div(force_lvl * force_lvl * force_lvl, 10)

        if div(force_lvl, 2) + rng.(force_lvl) > target_ce do
          [hit_msg, "只见" <> character.name <> "身子轻轻晃动几下，就不再动弹了。"]
        else
          [hit_msg, "哪里想到" <> character.name <> "挨了这一击，竟然若无其事，顿时一个翻身，直扑向$N！"]
        end
      else
        ["然而" <> character.name <> "身子一闪，躲了过去。"]
      end

    conn =
      Enum.reduce(msgs, conn, fn msg, conn ->
        Broadcast.publish(conn, Messages.interpolate(msg, n1: attacker.name, n2: character.name))
      end)

    Performs.feedback(attacker, 50, 2)

    put_character(conn, character)
  end

  # #include <ansi.h>
  # #include <skill.h>
  # #include <weapon.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int lvl;
  #  
  #         weapon = me->query_temp("weapon");
  # 
  #         if (! target)
  #                 return notify_fail("你要打哪条蛇？\n");
  # 
  #         if (! target->is_snake())
  #                 return notify_fail("看清楚些，那不是蛇，你瞎打什么？\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("那条蛇暂时不会动弹了，你不必再打了。\n");
  # 
  #         if ((int)me->query_skill("shedu-qiqiao", 1) < 20)
  #                 return notify_fail("你的蛇毒奇巧还不够娴熟，不能打蛇。\n");
  # 
  #         if ((int)me->query_skill("force") < 30)
  #                 return notify_fail("你的内功的修为不够，不能打蛇。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在的内力不够了。\n");
  # 
  #         if (weapon)
  #                 msg = HIC "\n$N" HIC "舞动手中的" + weapon->name() +
  #                       HIC "，朝着" + target->name() + HIC "的七寸打"
  #                       "了过去。\n" NOR;
  #         else
  #                 msg = HIC "\n$N" HIC "伸出双指，出指如风，迅疾无比的"
  #                       "朝着" + target->name() + HIC "的七寸点了过去"
  #                       "。\n" NOR;
  # 
  #         lvl = (int) me->query_skill("shedu-qiqiao", 1) +
  #               (int) me->query_skill("dodge");
  #         lvl = lvl * lvl / 10 * lvl;
  # 
  #         if( lvl / 2 + random(lvl) > (int) target->query("combat_exp") )
  #         {
  #                 msg += HIY "结果只听“啪”的一声，正打在" + target->name() +
  #                        HIY "的七寸上。\n" NOR;
  #                 lvl = (int) me->query_skill("force");
  #                 lvl = lvl * 13 / 10;
  #                 lvl = lvl * lvl / 10 * lvl;
  #                 if ( lvl / 2 + random(lvl) > (int) target->query("combat_exp") )
  #                 {
  #                         msg += HIM "只见" + target->name() + HIM
  #                                "身子轻轻晃动几下，就不再动弹了。\n" NOR;
  #                         message_vision(msg, me);
  #                         target->unconcious();
  #                 } else
  #                 {
  #                         msg += HIR + "哪里想到" + target->name() +
  #                                HIR "挨了这一击，竟然若无其事，顿时一个翻"
  #                                "身，直扑向$N" HIR "！\n\n" NOR;
  #                         message_vision(msg, me);
  #                         target->kill_ob(me);
  #                 }
  #         } else
  #         {
  #                 msg += WHT "然而" + target->name() + WHT "身子一闪，躲了过去。\n\n" NOR;
  #                 message_vision(msg, me);
  #                 target->kill_ob(me);
  #         }
  #         me->add("neili", -50);
  #         me->start_busy(2);
  # 
  #         return 1;
  # }
end
