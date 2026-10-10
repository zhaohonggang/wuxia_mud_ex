defmodule Kantele.Combat.Skills.Performs.ZhengliangyiJian.Sui do
  @moduledoc """
  perform「玉碎昆冈」（source zhengliangyi-jian/sui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"damage", "force"}, {"dp", "force"}], "level_gates": [{"force", "250"}, {"zhengliangyi-jian", "180"}], "map_gates": [{"sword", "zhengliangyi-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的正两仪剑法不够娴熟，难以施展", "你的内功火候不足，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "你没有激发正两仪剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "仰天一声惨笑，将" + weapon->name() + HIY
      #                 "剑尖指向自己胸口，剑柄斜斜向外，连人带剑电射而出，直"
      #                 "扑$n" HIY "而去！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage,
      #                                  150, pmsg)", "= HIY "可是$n" HIY "早已料到$N"
      #                          HIY "有此一着，身形急动，躲开"
      #                          "了这一杀着。\n" NOR"], "success": ["= HIY "可是$n" HIY "一声冷哼，飞身闪开来招，又顺势转身一"
      #                                  "掌拍向$N" HIY "面门。\n" NOR + HIR "只听“喀嚓”一声"
      #                                  "，$n" HIR "那掌正好打在$N" HIR "头顶，$N" HIR "哀嚎一"
      #                                  "声，软软的瘫倒。\n" NOR", "= HIR "$n" HIR "眼见$N" HIR "来势如此凶悍，这一招决计无"
      #                                  "法抵挡，骇怖达于极点，竟致僵立，束手待毙。\n只听“噗"
      #                                  "嗤”一声，" + weapon->name() + HIR "已然透过$n" HIR
      #                                  "前胸而入，喷出一股血雨。\n" NOR", "= HIR "$n" HIR "眼见$N" HIR "来势如此凶悍，只觉这一招决"
      #                                  "计无法抵挡，骇怖达于极点，慌乱之中一掌猛拍而出，击\n"
      #                                  "向$N" HIR "面门，竟也是同归于尽的招数。只听“噗嗤”一"
      #                                  "声，" + weapon->name() + HIR "已然透过$n" HIR "前胸，"
      #                                  "喷出一股血雨。\n同时$n" HIR "那一掌也正好打在$N" HIR
      #                                  "头顶，听得“喀嚓”一声，$N" HIR "头盖骨完全碎裂，软软"
      #                                  "的瘫倒。\n" NOR", "HIR "$n" HIR "眼见$N" HIR "来势如此凶悍，只觉这一招决"
      #                                  "计无法抵挡，急忙飞身闪避，然而只听“嗤啦”一声，那\n"
      #                                  "柄" + weapon->name() + HIR "已然刺穿" + limb + HIR "，"
      #                                  "喷出一股血雨。\n" NOR"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 3 / 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"max_neili", "-50"}, {"max_neili", "-random(50)"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"max_neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(6);", "target->start_busy(2 + random(6));", "me->start_busy(8);"], "remote_damage": true, "set_flags": [{"neili", "0"}], "temp_set": ["die_reason"]}
      #   - me->start_busy(6);
      #   - target->start_busy(2 + random(6));
      #   - me->start_busy(8);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
