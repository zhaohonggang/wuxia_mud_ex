defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Tian do
  @moduledoc """
  perform「无法无天」（source kuihua-mogong/tian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "kuihua-mogong/tian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuihua-mogong")
    i = (6 + Engine.rand(rng, 5))
    count = 0

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "kuihua-mogong") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "kuihua-mogong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "kuihua-mogong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 340 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("$N默运葵花魔功，身形变得奇快无比，接连从不同的方位向$n攻出数招！
$n只觉得眼前一花，发现四周都是$N的身影，不由暗生惧意，接连后退。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack", "damage", "unarmed_damage"], "assign_refs": [{"count", "kuihua-mogong"}, {"lvl", "kuihua-mogong"}], "busy_lines": ["if (random(2) && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(4));"], "level_gates": [{"kuihua-mogong", "220"}], "map_gates": [{"force", "kuihua-mogong"}, {"sword", "kuihua-mogong"}], "prepared_gates": [{"unarmed", "kuihua-mogong"}], "remote_damage": false, "resource_gates": [{"max_neili", "3400"}, {"neili", "340"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wu.c 无法无天
  # // 武器或者空手，手里拿剑或者针都可以
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define WU "「" HIC "无法无天" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/kuihua-mogong/tian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(WU "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query("neili") < 340)
  #         return notify_fail("你的真气不够，无法施展" WU "！\n");
  # 
  #     if ((lvl = me->query_skill("kuihua-mogong", 1)) < 220)
  #         return notify_fail("你的葵花魔功火候不够，无法施展" WU "！\n");
  # 
  #         if (me->query_skill_mapped("force") != "kuihua-mogong")
  #                 return notify_fail("你还没有激发葵花魔功为内功，无法施展" WU "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3400)
  #                 return notify_fail("你的内力修为不足，难以施展" WU "。\n");
  # 
  #         if (weapon = me->query_temp("weapon"))
  #         {
  #                 if (weapon->query("skill_type") != "sword" &&
  #                     weapon->query("skill_type") != "pin")
  #                         return notify_fail("你手里拿的不是剑，怎么施"
  #                                            "展" WU "？\n");
  #         } else
  #         {
  #                 if (me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                         return notify_fail("你并没有准备使用葵"
  #                                            "花魔功，如何施展" WU "？\n");
  #         }
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" WU "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "kuihua-mogong")
  #                 return notify_fail("你没有准备使用葵花魔功，难以施展" WU "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "默运葵花魔功，身形变得奇快无比，接连从不同的方位向$n"
  #               HIR "攻出数招！\n" NOR;
  #         i = 6  + random(5);    // 取消连招数判定条件，固定连击6~10次 BY MK
  #         if (lvl * 11 / 20 + random(lvl) > (int)target->query_skill("dodge", 1))
  #         {
  #                 msg += HIR "$n" HIR "只觉得眼前一花，发现四周都是$N"
  #                        HIR "的身影，不由暗生惧意，接连后退。\n" NOR;
  #                 count = me->query_skill("kuihua-mogong", 1) / 4;
  #                 me->add_temp("apply/attack", count);
  #                 //增强伤害
  #                 me->add_temp("apply/damage", count);
  #                 me->add_temp("apply/unarmed_damage", count);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "身法好快，哪里"
  #                        "敢怠慢，连忙打起精神小心应对。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -i * 30);
  # 
  #         while (i--)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(2) && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count);
  #         me->add_temp("apply/unarmed_damage", -count);
  #     me->start_busy(1 + random(4));
  #     return 1;
  # }
end
