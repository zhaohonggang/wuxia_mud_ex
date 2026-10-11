defmodule Kantele.Combat.Skills.Performs.LingyuanXinfa.Break do
  @moduledoc """
  exert「break」（source lingyuan-xinfa/break.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "lingyuan-xinfa") < 150 -> {:error, "你的灵元心法火候不够，还不会使用「以柔破钢」。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（can_perform/战斗/目标状态/临时状态/道具等）需人工核对：
    #   {:error, "你只能对战斗中的对手使用「以柔破钢」。\n"}
    #   {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    conn = Broadcast.publish(conn, "$N沉肩滑步，自丹田中升起一股阴柔之气顺着血脉经络传至双手劳宫穴，接着这股阴柔之气就激射而出，喷向$n手中的兵刃！", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"busy_lines": ["if (target->is_busy())", "me->start_busy(2);", "target->start_busy((int)me->query_skill("lingyuan-xinfa") / 20);"], "level_gates": [{"lingyuan-xinfa", "150"}], "remote_damage": false}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // break -「以柔破钢」
  # // made by deaner
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # int exert(object me, object target)
  # {
  #         string msg;
  #         object target_w;
  # 
  #         target_w = target->query_temp("weapon");
  # 
  #         if (! target || target == me)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能对战斗中的对手使用「以柔破钢」。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正在发愣，是进攻的好时机！\n");
  # 
  #         if ((int)me->query_skill("lingyuan-xinfa", 1) < 150)
  #                 return notify_fail("你的灵元心法火候不够，还不会使用「以柔破钢」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "沉肩滑步，自丹田中升起一股阴柔之气"
  #               "顺着血脉经络传至双手劳宫穴，接着这股阴柔之气就"
  #               "激射而出，喷向$n" HIC "手中的兵刃！\n" NOR;
  #         me->start_busy(2);
  # 
  #         if (target->query_temp("weapon") || target->query_temp("secondary_weapon"))
  #         {
  #                 if (random(me->query("combat_exp")) >
  #                     (int)target->query("combat_exp") / 3)
  #                 {
  #                         msg += HIW "结果$p" HIW "手中的" +
  #                                target_w->query("name") +
  #                                "与这股阴柔之气一碰竟被震落在地上！\n" NOR;
  #                         target_w->unequip();
  #                         target_w->move(environment(target));
  #                         target->reset_action();
  #                         target->start_busy((int)me->query_skill("lingyuan-xinfa") / 20);
  #                 } else
  #                 {
  #                         msg += CYN "可是$p" CYN "急急拆招，躲了"
  #                                "开去，使$P" CYN "的计谋没有得逞。\n" NOR;
  #                 }
  #                 message_combatd(msg, me, target);
  #                 return 1;
  #         }
  #         return notify_fail(target->name() + "目前是空手，没什么必要施展「以柔破钢」。\n");
  # }
end
