defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Powerup do
  @moduledoc """
  exert「powerup」（source xuedao-dafa/powerup.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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

  # LPC: if ((int)me->query("neili") < 150)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 150 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (target != me)
  defp check_target(_character) do
    _ = "你只能用血刀大法来提升自己的战斗力。\n"
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

    skill = Stats.skill(character.meta.stats, "xuedao-dafa")
    bonus = div(skill, 3)

    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: bonus, defense: bonus, damage: bonus})

    combat =
      Combat.add_buff(combat, %Kantele.Character.Combat.Buff{
        key: "powerup",
        applies: %{attack: -bonus, defense: -bonus, damage: -bonus},
        duration: skill
      })

    # LPC: if (me->is_fighting()) me->start_busy(1 + random(3));
    combat =
      if Combat.fighting?(combat),
        do: Combat.start_busy(combat, 1 + :rand.uniform(3)),
        else: combat

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn =
      Broadcast.publish(
        conn,
        "$N仰天一声狂哮，全身骨骼爆响，真气荡漾，杀气弥漫，气势迫人。\n",
        n1: character.name
      )

    # LPC: 手持 blade 且 mapped("blade")=="xuedao-dafa" 时的额外广播
    conn =
      case Combat.weapon(character.meta.combat) do
        %{skill_type: "blade", name: weapon_name} ->
          Broadcast.publish(
            conn,
            "$N嗔目狞笑，手中" <> weapon_name <> "顿时漾起一道血光，漫起无边杀意。\n",
            n1: character.name
          )

        _ ->
          conn
      end

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC remove_effect：tell_object(me, "你的血刀大法运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的血刀大法运行完毕，将内力收回丹田。\n"

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "damage", "defense"], "assign_refs": [{"skill", "xuedao-dafa"}], "busy_lines": ["me->start_busy(1 + random(3));"], "remote_damage": false, "resource_gates": [{"neili", "150"}], "temp_set": ["powerup"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         object weapon;
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用血刀大法来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("xuedao-dafa", 1);
  # 
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIR "$N" HIR "仰天一声狂哮，全身骨骼爆响，真气荡漾，杀"
  #                         "气弥漫，气势迫人。\n" NOR, me);
  # 
  #         if (objectp(weapon = me->query_temp("weapon")) &&
  #            (string)weapon->query("skill_type") == "blade" &&
  #            me->query_skill_mapped("blade") == "xuedao-dafa")
  #         {
  #             message_combatd(HIR "$N" HIR "嗔目狞笑，手中" + weapon->name() +
  #                                 HIR "顿时漾起一道血光，漫起无边杀意。\n" NOR, me);
  #         }
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #         me->add_temp("apply/damage", skill / 3);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 3, skill / 3 :), skill);
  #         if (me->is_fighting())
  #             me->start_busy(1 + random(3));
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/defense", -amount);
  #                 me->add_temp("apply/damage", -amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的血刀大法运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
