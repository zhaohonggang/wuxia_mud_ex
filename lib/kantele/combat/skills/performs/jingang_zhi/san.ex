defmodule Kantele.Combat.Skills.Performs.JingangZhi.San do
  @moduledoc """
  perform「一指点三脉」（source jingang-zhi/san.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"damage", "finger"}, {"dp", "parry"}, {"lvl", "jingang-zhi"}], "level_gates": [{"force", "300"}, {"jingang-zhi", "200"}, {"jingluo-xue", "200"}], "map_gates": [{"finger", "jingang-zhi"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [{"finger", "jingang-zhi"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你大力金刚指不够娴熟，难以施展", "你现在没有激发少林内功为内功，难以施展", "你对经络学了解不够，难以施展", "你没有激发大力金刚指，难以施展", "你没有准备大力金刚指，难以施展", "你的内功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "镇定自如，全力化解了$P"
      #                          CYN "这精妙的一指。\n" NOR"], "other": ["HIW "突然间""], "success": ["= "$N" HIW "凝气于指，「" HIR "一指点三脉" HIW "」点出，顿时一股"
      #                  "纯阳的内力直袭$n" HIW "胸口！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                                              HIR "结果$n" HIR "被$N" HIR "一指点中"
      #                                              HIY + xue_name[random(sizeof(xue_name))] +
      #                                              HIR "，全身真气逆流而上，登时呕出一大"
      #                                              "口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("finger") + (int)me->query_skill("force") + (int)me->query_skill("jinluo-xue",1)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-800"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-800"}], "affect_by": [], "apply_adds": [], "busy_lines": ["target->start_busy(lvl/30);", "me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - target->start_busy(lvl/30);
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
