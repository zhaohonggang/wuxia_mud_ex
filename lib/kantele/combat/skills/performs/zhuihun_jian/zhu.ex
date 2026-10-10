defmodule Kantele.Combat.Skills.Performs.ZhuihunJian.Zhu do
  @moduledoc """
  perform「诛天刹神」（source zhuihun-jian/zhu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "zhuihun-jian"}, {"damage", "force"}, {"dp", "parry"}], "level_gates": [{"zhuihun-jian", "160"}], "map_gates": [{"sword", "zhuihun-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你没有激发追魂夺命剑，难以施展", "你的追魂夺命剑还不够娴熟，难以施展", "你现在内力太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("zhuihun-jian", 1) +
      #                me->query_skill("sword", 1)", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["HIW "突然$N" HIW "一声冷哼，一个跨步，手中" + weapon->name() +
      #                 NOR + HIW "中攻直进，如闪电一般刺向$n" HIW "！\n" NOR", "= COMBAT_D->do_damage(me, target,
      #                                  WEAPON_ATTACK, damage, 70, pmsg)", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，避开了这一招。\n"NOR"], "success": ["= HIR "只见$N" HIR "这一剑来势好快，便听“嗤"
      #                                  "啦”一声，剑尖已没入$n" HIR "咽喉半尺，$n"
      #                                  HIR "咯咯叫了两声，软绵绵的瘫了下去。\n" NOR
      #                                  "( $n" RED "受伤过重，已经有如风中残烛，随"
      #                                  "时都可能断气。" NOR ")\n"", "= HIR "只听“嗤啦”一声，$n" HIR "腕部已被$N"
      #                                  HIR + weapon->name() + NOR + HIR "对穿而过"
      #                                  "，手中" + weapon2->name() + NOR + HIR
      #                                  "再也捉拿不住，脱手而飞！\n" NOR", "HIR "$n" HIR "飞身躲闪，然而只听“嗤啦”"
      #                                  "一声，$N" HIR + weapon->name() + NOR +
      #                                  HIR "已没入$n" HIR + limb + "半寸，鲜血"
      #                                  "狂溅而出。\n" NOR"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(random(2));", "target->start_busy(4);", "target->start_busy(1 + random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(random(2));
      #   - target->start_busy(4);
      #   - target->start_busy(1 + random(3));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
