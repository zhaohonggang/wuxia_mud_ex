defmodule Kantele.Combat.Skills.Performs.SadStrike.Xiao do
  @moduledoc """
  perform「黯然销魂」（source sad-strike/xiao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "sad-strike/xiao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = (Stats.skill(stats, "unarmed") + Stats.skill(stats, "force"))
    lvl = Stats.skill(stats, "sad-strike")
    n = 6
    count = 0
    i = 0

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
      Stats.skill(stats, "force") < 320 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sad-strike") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    result = Messages.interpolate("$N一声长吟：“黯然销魂者，唯别而已矣！”，顿时心如止水，黯然神伤，于不经意中随手使出了『黯然销魂』！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack"], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"lvl", "sad-strike"}], "busy_lines": ["if (random(2) && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "level_gates": [{"force", "320"}, {"sad-strike", "150"}], "prepared_gates": [{"unarmed", "sad-strike"}], "remote_damage": false, "resource_gates": [{"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // xiao.c 黯然销魂
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define XIAO "「" HIW "黯然销魂" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int lvl, count;
  #         int i, n;
  # 
  #         if (userp(me) && ! me->query("can_perform/sad-strike/xiao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAO "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(XIAO "只能空手使用。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #         if ((int)me->query_skill("sad-strike", 1) < 150)
  #                 return notify_fail("你的黯然销魂掌火候不够，无法施展" XIAO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 320)
  #                 return notify_fail("你的内功修为不够，无法施展" XIAO "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "sad-strike")
  #                 return notify_fail("你现在没有准备使用黯然销魂掌，无法施展" XIAO "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "\n$N" HIM "一声长吟：“黯然销魂者，唯别而已矣！”，顿时心如"
  #               "止水，黯然神伤，于不经意中随手使出了" HIR "『黯然销魂』" HIM "！\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  #         lvl = me->query_skill("sad-strike", 1);
  #         n = 6;
  # 
  #         if (lvl > 600)
  #             n += (int)(lvl - 400) / 200;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 10;
  #                 msg += HIY "$n" HIY "见$P" HIY "这一招变化莫测，奇幻无"
  #                        "方，不由大吃一惊，慌乱中破绽迭出。\n" NOR;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "不敢小觑$P" HIC
  #                        "的来招，腾挪躲闪，小心招架。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_sort(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -70 * n);
  #         for (i = 0; i < n; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(2) && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(2 + random(4));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
