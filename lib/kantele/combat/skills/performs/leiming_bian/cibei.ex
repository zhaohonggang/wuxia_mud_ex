defmodule Kantele.Combat.Skills.Performs.LeimingBian.Cibei do
  @moduledoc """
  perform「cibei」（source leiming-bian/cibei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"at", "leiming-bian"}, {"df", "dodge"}, {"extra", "leiming-bian"}, {"lmt", "leiming-bian"}, {"skill", "buddhism"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "1500"}, {"shen", "200000"}], "var_gates": [{"extra", "160"}, {"lmt", "3"}, {"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你使用的外功中没有这个功能。\n", "［慈悲字诀］只能对战斗中的对手使用。\n", "你的雷鸣鞭法修为太差,还不能使用慈悲字诀！\n", "你的禅宗心法等级不够，怎能支持慈悲字诀？ \n", "慈悲字诀需以无边正气为辅,大师还是多行善事吧! \n", "你的内力修为不够辅助慈悲字诀。\n", "你手中没有兵器如何使用慈悲字诀。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["RED "只见$N喃喃自语道：慈悲为怀，手中的" + weapon->name() + RED "仿佛如来出世般倒卷向$n。\n" NOR", "= CYN "$n不禁被$N的无边佛法打动，猛的后退，脸上没有一丝血色...\n" NOR", "= "( $n" + eff_status_msg(p) + " )\n"", "HIG "\n紧接着$N手中的" + weapon->name() + HIG "连续晃动，竟然不知道有多少击。\n" NOR", "HIG "\n$n左躲右闪，强$N的攻击完全化于无形！\n" NOR"], "success": []}, "damage_formula": %{"formula": "me->query("shen", 1) / 2000"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 3", "kind": "wound", "part": "qi", "source": "me"}], "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["target->start_busy(3);", "me->start_busy(random(2) + 2);", "me->start_busy(random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - target->start_busy(3);
      #   - me->start_busy(random(2) + 2);
      #   - me->start_busy(random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
