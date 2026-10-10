defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Die do
  @moduledoc """
  perform「阳关三叠」（source yiyang-zhi/die.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "300"}, {"jingluo-xue", "200"}, {"yiyang-zhi", "200"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你一阳指诀不够娴熟，难以施展", "你对经络学了解不够，难以施展", "你没有激发一阳指诀，难以施展", "你没有准备一阳指诀，难以施展", "你的内功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": ["= CYN "可是$n" CYN "将手中" + wp + NOR + CYN "转"
      #                                  "动如轮，终于化解了这一招。\n\n" HIW "紧接着"", "= CYN "可是$p" CYN "镇定自如，全力化解了$P"
      #                          CYN "这精妙的一指。\n" NOR", "= CYN "可是$p" CYN "镇定自如，全力化解了$P"
      #                          CYN "这精妙的一指。\n" NOR", "= CYN "可是$p" CYN "镇定自如，全力化解了$P"
      #                          CYN "这精妙的一指。\n" NOR"], "other": ["HIW "突然间"", "= "$N" HIW "单指一扬，径点$n" HIW "持着" + wp + NOR + HIW
      #                          "的手腕上「" HIY "腕骨" HIW "」、「" HIY "阳谷" HIW "」"
      #                          "、「" HIY "养老" HIW "」三穴。\n" NOR", "= "\n" HIW "接着$N" HIW "踏前一步，体内真气迸发，隔空一指劲点$n" HIW
      #                  "而去，指气纵横，嗤然作响！\n" NOR", "= "\n" HIW "最后$N" HIW "一声猛喝，单指“嗤”的一声点出，纯阳指力同"
      #                  "时笼罩$n" HIW "全身诸多要穴！\n" NOR", "= HIY "\n$n" HIY "被$N" HIY "三指连中，全身真气涣"
      #                          "散，宛如黄河决堤，内力登时狂泻而出。\n\n" NOR"], "success": ["= HIR "霎时间$n" HIR "只觉得手腕一麻，手中" + wp +
      #                                  HIR "再也拿持不住，脱手掉在地上。\n\n" HIW "紧"
      #                                  "接着"", "= "$N" HIW "凝气于指，一式「" HIR "阳关三叠" HIW "」点出，顿时一股"
      #                  "纯阳的内力直袭$n" HIW "胸口！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              HIR "结果$n" HIR "被$N" HIR "一指点中"
      #                                              HIY + xue_name[random(sizeof(xue_name))] +
      #                                              HIR "，全身真气逆流而上，登时呕出一大"
      #                                              "口鲜血。\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                              HIR "结果$n" HIR "被$N" HIR "一指点中"
      #                                              HIY + xue_name[random(sizeof(xue_name))] +
      #                                              HIR "，全身真气逆流而上，登时呕出一大"
      #                                              "口鲜血。\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
      #                                              HIR "结果$n" HIR "被$N" HIR "一指点中"
      #                                              HIY + xue_name[random(sizeof(xue_name))] +
      #                                              HIR "，全身真气逆流而上，登时呕出一大"
      #                                              "口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}, {"neili", "-50"}, {"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}, {"neili", "-50"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["//me->start_busy(4 + random(4));", "me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - //me->start_busy(4 + random(4));
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
