defmodule Kantele.Combat.Skills.Performs.ShenghuoShengong.Shield do
  @moduledoc """
  exert「shield」（source shenghuo-shengong/shield.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
    stats = character.meta.stats
    skill = Stats.skill(stats, "shenghuo-shengong")

    with :ok <- check_gates(character) do
      apply_effect(conn, character, skill)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_gates(character) do
    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用圣火神功来提升自己的防御力。\n");
  defp check_target(_character) do
    _ = "你只能用圣火神功来提升自己的防御力。\n"
    :ok
  end

  # LPC: if ((int) me->query("neili") < 100)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 100 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (skill < 40)
  defp check_levels(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "shenghuo-shengong") < 40 do
      {:error, "你的圣火神功等级不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int) me->query_temp("shield"))
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, "shield") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, skill) do
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 2), else: combat

    # LPC: apply/armor += skill; set_temp("shield", 1)
    combat = Combat.apply_temp(combat, %{armor: skill})

    combat =
      Combat.add_buff(combat, %Kantele.Character.Combat.Buff{
        key: "shield",
        applies: %{armor: -skill},
        duration: skill
      })

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("$N默念圣火神功口诀，一股真气流至奇经八脉，护住全身。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC remove_effect：tell_object(me, "你的圣火神功运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的圣火神功运行完毕，将内力收回丹田。\n"

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["armor"], "assign_refs": [{"skill", "shenghuo-shengong"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "level_gates": [{"shenghuo-shengong", "40"}], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["shield"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用圣火神功来提升自己的防御力。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         if ((int)me->query_skill("shenghuo-shengong", 1) < 40)
  #                 return notify_fail("你的圣火神功等级不够。\n");
  # 
  #         if ((int)me->query_temp("shield"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("shenghuo-shengong", 1);
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIG "$N" HIG "默念圣火神功口诀，一股真气流至奇经八脉，护住全身。\n" NOR, me);
  # 
  #         me->add_temp("apply/armor", skill / 2);
  #         me->set_temp("shield", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 2 :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("shield"))
  #         {
  #                 me->add_temp("apply/armor", -amount);
  #                 me->delete_temp("shield");
  #                 tell_object(me, "你的圣火神功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
