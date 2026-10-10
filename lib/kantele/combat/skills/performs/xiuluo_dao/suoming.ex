defmodule Kantele.Combat.Skills.Performs.XiuluoDao.Suoming do
  @moduledoc """
  perform「suoming」（source xiuluo-dao/suoming.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"force", "200"}, {"xiuluo-dao", "135"}], "map_gates": [{"blade", "xiuluo-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「修罗索命」只能在战斗中对对手使用。\n", "你使用的武器不对。\n", "你的内功的修为不够，不能使用这一绝技！\n", "你的修罗刀法修为不够，目前不能使用修罗索命！\n", "你的真气不够，不能使用修罗索命！\n", "你没有激发修罗刀法，不能使用修罗索命！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "脸上杀气大盛，一振手中的" + weapon->name() +
      #                 HIC "，唰唰数刀将$n" + HIC "团团裹住！\n" NOR", "= CYN "可是$p" CYN "眼明手快，只听叮叮当当响起了一串"
      #                          CYN "刀鸣，$p" CYN "将$P" CYN "的招式全部挡开！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                              HIR "就听见$p" HIR "惨叫连连，一阵阵血雨自" HIR
      #                                              "亮白的刀光中溅出！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
