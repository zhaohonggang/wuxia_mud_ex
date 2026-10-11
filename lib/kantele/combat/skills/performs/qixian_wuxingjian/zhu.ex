defmodule Kantele.Combat.Skills.Performs.QixianWuxingjian.Zhu do
  @moduledoc """
  perform「七弦连环诛」（source qixian-wuxingjian/zhu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qixian-wuxingjian/zhu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qixian-wuxingjian")
    skill = Stats.skill(stats, "qixian-wuxingjian")
    ap = Stats.skill(stats, "force")
    count = div(ap, 15)
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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "qixian-wuxingjian" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
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
    vitals = %{vitals | neili: vitals.neili - 250}
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
    Performs.feedback(attacker, 250, 1)
    result = Messages.interpolate("$p只感到$P内力澎湃，汹涌而至，霎时心神惧碎，呆立当场！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-250"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "force"}, {"skill", "qixian-wuxingjian"}], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"force", "300"}], "map_gates": [{"sword", "qixian-wuxingjian"}], "prepared_gates": [{"unarmed", "qixian-wuxingjian"}], "remote_damage": false, "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "6"}, {"skill", "180"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHU "「" HIW "七弦连环诛" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         object weapon;
  #         int i;
  #         int skill;
  #         int ap, an, dn;
  #         int count;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/qixian-wuxingjian/zhu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(ZHU "只能对战斗中的对手使用。\n");
  # 
  #         skill = me->query_skill("qixian-wuxingjian", 1);
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功的修为不够，现在无法使用" ZHU "。\n");
  # 
  #         if (skill < 180)
  #                 return notify_fail("你的七弦无形剑修为有限，现在无法使用" ZHU "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法运用" ZHU "。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (weapon && weapon->query("skill_type") != "sword")
  #                 return notify_fail("你不能使用这种兵器施展" ZHU "。\n");
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "qixian-wuxingjian")
  #                 return notify_fail("你现在没有准备使用七弦无形剑，无法施展" ZHU "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "qixian-wuxingjian")
  #                 return notify_fail("你现在没有准备使用七弦无形剑，无法施展" ZHU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (weapon)
  #         {
  #                 msg = HIW "只见$N" HIW "双目微闭，单手在" + weapon->name() +
  #                       HIW "上轻轻拨动，顿时只听“啵啵啵”破空之声连续不断"
  #                       "，数股破\n体无形剑气激射而出，直奔$n" HIW "而去。\n" NOR;
  #         } else
  #         {
  #                 msg = HIW "只见$N" HIW "双目微闭，双手轻轻舞弄，陡然间十指一"
  #                       "并箕张，顿时只听“啵啵啵”破空之声连续不\n断，数股破"
  #                       "体无形剑气激射而出，直奔$n" HIW "而去。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("force");
  #         an = me->query("max_neili");
  #         dn = target->query("max_neili");
  # 
  #         if (an > dn)
  #         {
  #                 msg += HIR "$p" HIR "只感到$P" HIR "内力澎湃，汹涌而至，霎"
  #                        "时心神惧碎，呆立当场！\n" NOR;
  #                 count = ap / 8;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "只感到$P" HIC "内力澎湃，汹涌而至，急"
  #                        "忙凝神聚气，小心应付。\n" NOR;
  #                 count = ap / 15;
  #                 me->add_temp("apply/attack", count);
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -250);
  # 
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(3) == 0 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->start_busy(1 + random(6));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
