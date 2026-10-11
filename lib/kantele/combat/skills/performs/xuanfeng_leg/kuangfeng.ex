defmodule Kantele.Combat.Skills.Performs.XuanfengLeg.Kuangfeng do
  @moduledoc """
  perform「kuangfeng」（source xuanfeng-leg/kuangfeng.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuanfeng-leg/kuangfeng"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuanfeng-leg")
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
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "luoying-shenzhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuanfeng-leg") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
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
    Performs.feedback(attacker, 100, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"force", "150"}, {"luoying-shenzhang", "100"}, {"xuanfeng-leg", "100"}], "prepared_gates": [{"unarmed", "xuanfeng-leg"}], "remote_damage": false, "resource_gates": [{"neili", "150"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // kuangfeng.c  狂风绝技
  # 
  # #include <ansi.h>
  # #include <skill.h>
  # #include <weapon.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #   string msg;
  #     int i;
  # 
  #     if (! target)
  #     {
  #         me->clean_up_enemy();
  #             target = me->select_opponent();
  #     }
  # 
  #     if (! target || !me->is_fighting(target))
  #         return notify_fail("「狂风绝技」只能在战斗中对对手使用。\n");
  # 
  #     if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #         return notify_fail("「狂风绝技」开始时不能拿着兵器！\n");
  # 
  #     if ((int)me->query("neili") < 150)
  #         return notify_fail("你的真气不够！\n");
  # 
  #     if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你的内功水平不够！\n");
  # 
  #     if ((int)me->query_skill("luoying-shenzhang", 1) < 100 ||
  #         me->query_skill("xuanfeng-leg",1) < 100)
  #         return notify_fail("你的腿掌功夫还不到家，无法使用狂风绝技！\n");
  # 
  #     if (me->query_skill_prepared("unarmed") != "xuanfeng-leg")
  #         return notify_fail("你没有准备旋风腿法，无法施展狂风绝技。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "使出桃花岛绝技「狂风绝技」，身法飘忽"
  #               "不定，有若天仙！\n" NOR;
  #     message_combatd(msg, me);
  #     me->add("neili", -100);
  # 
  #     for (i = 0; i < 6; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 if (random(3) == 0 && ! target->is_busy())
  #                         target->start_busy(1);
  #         COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  # 
  #     me->start_busy(1 + random(6));
  #     return 1;
  # }
end
