defmodule Kantele.Combat.Skills.Performs.JinsheZhui.Feng do
  @moduledoc """
  perform「截脉封穴」（source jinshe-zhui/feng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "throwing"}, {"dp", "force"}, {"skill", "jinshe-zhui"}], "level_gates": [{"force", "150"}], "map_gates": [{"throwing", "jinshe-zhui"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": [{"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你才用过截脉封穴，没法接着就出招。\n", "截脉封穴只能在战斗中使用。\n", "你的内功的修为不够，难以施展", "你的金蛇锥法修为有限，难以施展", "你现在的真气不足，难以施展", "你没有激发金蛇锥法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("throwing")", "dp_formula": "target->query_skill("force")"}, "buff_delete": ["jinshe/feng"], "call_outs": [%{"args": "me", "delay": "5", "fn": "feng_end"}], "callback_functions": [%{"body": "me->delete_temp("jinshe/feng");", "name": "feng_end", "params": "object me", "return_type": "void"}], "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的招式，巧妙的一一拆解，没露半点破绽！\n" NOR"], "success": ["HIR "$N" HIR "飞身一跃而起，贴至$n" HIR "跟前，点向$n" HIR "要穴！\n" NOR", "= HIR "$p" HIR "微微一楞，已被$N" HIR
      #                   "点中要穴，顿时瘫软无力，缓缓瘫倒。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": ["armor", "damage", "defense", "dodge", "force", "parry"], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
