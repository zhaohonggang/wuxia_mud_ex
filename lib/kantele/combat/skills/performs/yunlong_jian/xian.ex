defmodule Kantele.Combat.Skills.Performs.YunlongJian.Xian do
  @moduledoc """
  perform「xian」（source yunlong-jian/xian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "force"}], "level_gates": [{"force", "120"}, {"yunlong-jian", "50"}], "map_gates": [{"sword", "yunlong-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["云龙三现只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的云龙剑法不够娴熟，不会使用「云龙三现」！\n", "你的内功火候不够，不能使用「云龙三现」。\n", "你没有激发云龙剑法，不能使用「云龙三现」！\n", "你现在真气不够，不能使用「云龙三现」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "微微一笑，猛吸一口气，以气驭剑攻击虚虚实实的攻向$n"
      #                 HIM "！\n" NOR", "= CYN "可是$p" CYN "猛地向前一跃，跳出了$P"
      #                          CYN "的攻击范围。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #                                      HIR "只见$N" HIR "手中剑光幻作一条金龙，腾空而"
      #                                              "起倏的罩向$n" HIR "，\n$p" HIR "只觉一股大力"
      #                                              "铺天盖地般压来，登时眼前一花，两耳轰鸣，哇的"
      #                                              "喷出一口鲜血！！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("force") / 2"}, "resource_adds": [{"neili", "-100"}, {"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
