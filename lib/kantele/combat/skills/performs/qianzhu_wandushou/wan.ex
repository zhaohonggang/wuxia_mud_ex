defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Wan do
  @moduledoc """
  perform「wan」（source qianzhu-wandushou/wan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qianzhu-wandushou/wan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qianzhu-wandushou")
    skill = Stats.skill(stats, "qianzhu-wandushou")
    delta = div(skill, 6)
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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["dodge", "parry", "unarmed_damage"], "assign_refs": [{"poison", "poison"}, {"skill", "qianzhu-wandushou"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"force", "300"}], "prepared_gates": [{"hand", "qianzhu-wandushou"}], "remote_damage": false, "resource_gates": [{"max_neili", "3500"}, {"neili", "500"}], "var_gates": [{"i", "5"}, {"skill", "220"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // mapping prepare;
  #         string msg;
  #         int skill;
  #         int delta;
  #         int i, count, poison;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/wan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("「万蛊噬天」只能对战斗中的对手使用。\n");
  # 
  #         //晕倒后不可以再出pfm by over 20180129
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (me->query_skill_prepared("hand") != "qianzhu-wandushou")
  #                 return notify_fail("你没有准备使用千蛛万毒手，无法施展万蛊噬天。\n");
  # 
  #         skill = me->query_skill("qianzhu-wandushou", 1);
  #         poison = me->query_skill("poison");
  # 
  #         if (skill < 220)
  #                 return notify_fail("你的千蛛万毒手修为有限，无法施展万蛊噬天。\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功火候不够，难以施展万蛊噬天。\n");
  # 
  #         if (me->query("max_neili") < 3500)
  #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内力施展万蛊噬天。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，现在无法施展万蛊噬天。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展万蛊噬天。\n");
  # 
  #         msg = RED "\n$N" RED "仰天一声长啸，强催内劲，全身"
  #               "竟浮现出隐隐碧绿之色。喝道：“万蛊噬天”,双"
  #               "掌猛\n然拍出，登时幻出漫天碧绿色掌影，毒气弥"
  #               "漫，笼罩$n" RED "全身！\n\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  #         delta = skill / 6;
  #         count = 0;
  #         me->add("neili", -300);
  #         if (me->query("family/family_name") == "五毒教")
  #             count = (int)(poison / 50) * 3;
  #         target->add_temp("apply/parry", -delta);
  #         target->add_temp("apply/dodge", -delta);
  #         me->add_temp("apply/unarmed_damage", count);
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         target->add_temp("apply/parry", delta);
  #         target->add_temp("apply/dodge", delta);
  #         me->add_temp("apply/unarmed_damage", -count);
  #         me->start_busy(1 + random(5));
  # 
  #         return 1;
  # }
end
