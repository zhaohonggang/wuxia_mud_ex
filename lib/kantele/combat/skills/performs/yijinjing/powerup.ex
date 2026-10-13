defmodule Kantele.Combat.Skills.Performs.Yijinjing.Powerup do
  @moduledoc """
  exert「powerup」（source yijinjing/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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

  defp check_gates(character) do
    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 200 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (target != me)
  defp check_target(_character) do
    _ = "你只能提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query_temp("powerup"))
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    skill = Stats.skill(character.meta.stats, "yijinjing")
    bonus = div(skill, 3)

    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: bonus, defense: bonus})

    combat =
      Combat.add_buff(combat, %Kantele.Character.Combat.Buff{
        key: "powerup",
        applies: %{attack: -bonus, defense: -bonus},
        duration: skill
      })

    # LPC: if (me->is_fighting()) me->start_busy(1 + random(3));
    combat =
      if Combat.fighting?(combat),
        do: Combat.start_busy(combat, 1 + :rand.uniform(3)),
        else: combat

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish(
      "$N淡淡一笑，脸现慈和之意，衣裳无风自动，似乎有一股气流回旋。\n",
      n1: character.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC remove_effect：tell_object(me, "你的易筋经神功运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的易筋经神功运行完毕，将内力收回丹田。\n"

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "defense"], "assign_refs": [{"skill", "yijinjing"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(1 + random(3));"], "remote_damage": false, "resource_gates": [{"neili", "200"}], "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c 易筋经加力
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #     int skill;
  # 
  #     if (target != me)
  #         return notify_fail("你只能提升自己的战斗力。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你的真气不够。\n");
  # 
  #     if ((int)me->query_temp("powerup"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     skill = me->query_skill("yijinjing", 1);
  # 
  #     message_combatd(HIR "$N" HIR "淡淡一笑，脸现慈和之意，衣裳无"
  #                         "风自动，似乎有一股气流回旋。\n" NOR, me);
  # 
  #     me->add_temp("apply/attack", skill / 3);
  #     me->add_temp("apply/defense", skill / 3);
  #     me->set_temp("powerup", 1);
  #     me->add("neili", -100);
  # 
  #     me->start_call_out( (: call_other, __FILE__, "remove_effect", me, skill / 3 :), skill);
  # 
  #     if (me->is_fighting()) me->start_busy(1 + random(3));
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #             me->add_temp("apply/attack", - amount);
  #             me->add_temp("apply/defense", - amount);
  #             me->delete_temp("powerup");
  #             tell_object(me, "你的易筋经神功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
