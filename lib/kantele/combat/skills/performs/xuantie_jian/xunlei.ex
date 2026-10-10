defmodule Kantele.Combat.Skills.Performs.XuantieJian.Xunlei do
  @moduledoc """
  perform「xunlei」（source xuantie-jian/xunlei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"j", "xuantie-jian"}, {"z", "surge-force"}], "level_gates": [{"force", "200"}, {"surge-force", "160"}, {"xuantie-jian", "160"}], "map_gates": [{"parry", "xuantie-jian"}, {"sword", "xuantie-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "900"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你未得高人指点，不知该如何施展「迅雷击」。\n", "「迅雷击」只能在战斗中对对手使用。\n", "你必须在使用剑时才能使出「迅雷击」！\n", "你的基本招架必须是玄铁剑法时才能使出「迅雷击」！\n", "你必须激发玄铁剑法才能使出「迅雷击」！\n", "你的玄铁剑法还不够娴熟，使不出「迅雷击」。\n", "你的怒海狂涛修为不够，使不出「迅雷击」。\n", "你的内功等级不够，使不出「迅雷击」。\n", "你的膂力还不够，使不出「迅雷击」。\n", "你的身法还不够，使不出「迅雷击」。\n", "你现在内力太弱，使不出「迅雷击」。\n", "你现在真气太弱，使不出「迅雷击」。\n"], "color_codes": ["BLU", "NOR"], "combat_messages": %{"fail": [], "other": ["BLU "\n$N将手中的"+weapon->name()+"缓缓向$n一压，忽然剑光一闪， 一剑幻为三剑，宛如奔雷掣电攻向$n！\n\n"NOR"], "success": []}, "resource_adds": [{"neili", "-350"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-350"}], "affect_by": [], "apply_adds": ["attack", "str"], "busy_lines": ["me->start_busy(3);", "if( !target->is_busy() )", "target->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - if( !target->is_busy() )
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
