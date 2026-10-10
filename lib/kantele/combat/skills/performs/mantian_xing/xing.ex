defmodule Kantele.Combat.Skills.Performs.MantianXing.Xing do
  @moduledoc """
  perform「穹外飞星」（source mantian-xing/xing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "mantian-xing"}], "level_gates": [{"force", "150"}, {"mantian-xing", "80"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1200"}, {"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你现在手中没有拿着暗器，难以施展", "至少要有十五枚暗器才能施展", "你的满天星不够娴熟，难以施展", "你的内功修为不足，难以施展", "你的内力修为不足，难以施展", "你现在真气不足，难以施展", "对方已经中了你的绝招，现在是废人一个，赶快进攻吧！\n", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "amount_gates": ["15"], "buff_delete": ["feixing"], "callback_functions": [%{"body": "if (objectp(target))
      #           {
      #                   target->add_temp("apply/attack", 70);
      #                   target->add_temp("apply/dodge", 70);
      #                   target->add_temp("apply/parry", 20);
      #            ", "name": "back", "params": "object target", "return_type": "void"}], "color_codes": ["CYN", "HIC", "HIR", "HIY", "NOR", "RED"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["COMBAT_D->query_ahinfo()))
      #                                   msg += pmsg", "= "( $n" + eff_status_msg(p) + " )\n"", "= "( $n" + eff_status_msg(p) + " )\n"", "= CYN "可是$n" CYN "小巧腾挪，好不容易避开了"
      #                           CYN "$N" CYN "铺天盖地的攻击。\n" NOR"], "success": ["HIR "$N" HIR "蓦地飞身跃起，十指箕张，施出「穹外飞星」将"
      #                 "手中" + weapon->name() + HIR "尽数凌空射出。\n霎时破空声"
      #                 "骤响，" + weapon->name() + HIR "便如同陨星飞坠一般，笼罩"
      #                 "$n" HIR "各处大穴！\n" NOR", "= HIR "结果$n" HIR "一声惨叫，同时中了$P" HIR +
      #                                  chinese_number(n) + weapon->query("base_unit") +
      #                                  weapon->name() + HIR "，直感两耳轰鸣，目不视"
      #                                  "物。\n" NOR", "= HIR "$n" HIR "集中生智，双手画圈回旋挥舞，拨弄"
      #                                  "开了要害处的杀着，可还是受了点轻伤。\n" NOR"]}, "exp_compare": [{"my_exp", "ob_exp"}], "hit_ob_calls": [{"me", "target", "me->query("jiali") + 100 + n * 10"}], "receive_damage_calls": [%{"formula": "150", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "50", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "100", "kind": "damage", "part": "qi", "source": None}, %{"formula": "40", "kind": "wound", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "dodge", "parry"], "busy_lines": ["me->start_busy(1 + random(2));", "me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["feixing"]}
      #   - me->start_busy(1 + random(2));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
