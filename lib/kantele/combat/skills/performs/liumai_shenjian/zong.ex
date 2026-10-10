defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Zong do
  @moduledoc """
  perform「万剑纵横」（source liumai-shenjian/zong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"ap", "liumai-shenjian"}, {"damage", "finger"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}, {"skill", "liumai-shenjian"}], "level_gates": [{"force", "480"}], "map_gates": [], "prepared_gates": [{"finger", "liumai-shenjian"}], "resource_gates": [{"max_neili", "8500"}, {"neili", "1000"}], "var_gates": [{"skill", "260"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你没有准备使用六脉神剑，无法施展", "你的六脉神剑修为有限，无法使用", "你的内功火候不够，难以施展", "你的内力修为不够,无法施展", "你的真气不够，现在无法施展", "你必须是空手才能施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1)", "dp_formula": "target->query_skill("force",1)+target->query_skill("jingluo-xue", 1)"}, "color_codes": ["CYN", "HIB", "HIC", "HIG", "HIM", "HIR", "HIW", "HIY", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "一声清啸，十指纷弹，顿觉六脉剑谱已涌上心头，此起"
      #                 "彼伏、连绵不绝。霎时剑气如奔，连绵无尽的万道剑气豁然贯向$n" HIM
      #                 "！\n" NOR", "= HIY "但见$n" HIY "会心一笑，轻拂衣袖，轻易的躲过这一招！\n"NOR", "= CYN "$n" CYN "见$N" CYN "来势汹涌，不敢轻易"
      #                          "招架，急忙提气跃开。\n" NOR", "= HIM "$N" HIM "双手拇指同时捺出，嗤嗤两声急响，「"+ HIY "少商剑"+ HIM "」有如石破天惊、风雨大至。\n" NOR", "= CYN "$n" CYN "使出浑身解数，终于将$N"
      #                          CYN "这一指架开，丝毫无损。\n" NOR", "= CYN "$n" CYN "使出浑身解数，终于将$N"
      #                          CYN "这一指架开，丝毫无损。\n" NOR", "= HIG "只见" HIG "$N" HIG "右手中指一竖，「" HIC "中冲剑" HIG "」向前刺出。真气鼓荡，嗤然声响，无形剑气直指$n。 \n"NOR", "= CYN "$n" CYN "使出浑身解数，终于将$N"
      #                          CYN "这一指架开，丝毫无损。\n" NOR", "= HIC "$N" HIC "无名指轻轻一挥，「嗤啦」一声，拙滞古朴的「" MAG "关冲剑" HIC "」剑气向" HIC"$n" HIC"直射而出。\n"NOR", "= CYN "$n" CYN "左闪右跳，终于将$N"
      #                          CYN "这一指避开，丝毫无损。\n" NOR", "= HIB "忽见$N" HIB "左手小指一伸，一条气流从少冲穴中激射而出，一股「" HIW "少泽剑" HIB "」登时射向$n。\n"NOR", "= CYN "$n" CYN "运气抵挡，硬生生接下了$N"
      #                          CYN "这一指。\n" NOR", "= HIW "最后"HIW "$N" HIW"右手小指一挥，一招「" HIG "少冲剑" HIW "」点点刺刺破空刺出，宛如雕花刺画一般。\n"NOR", "= CYN "$n" CYN "运气抵挡，终于接下了$N"
      #                          CYN "这一指，已是狼狈不堪。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 200,
      #                                              HIR "只听$n" HIR "一声惨叫，万道剑气已"
      #                                              "透体而过，伤口处鲜血顿时狂涌，痛苦难当！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$n" HIR "奋力抵挡，却哪里招架得住，被$N"
      #                                              HIR "这一指戳得鲜血迸流！\n" NOR)", "= HIY "接着" HIY "$N" HIY "拇指一屈，食指随即点出，嗤嗤两声急响，「" HIR "商阳剑" HIY "」激射刺出。\n"NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$n" HIR "试图抵挡，只听哧的一声，"
      #                                              HIR "无形剑气已破体而入，透体而出！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                              HIR "$n" HIR "一愣，只听哧啦的一声，"
      #                                              HIR "已被剑气划得鲜血飞溅！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                              HIR "$n" HIR "躲闪不及，被戳了碗口大个血窟窿，"
      #                                              HIR "鲜血喷涌而出！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "运气抵挡，只觉得一股透体凉意"
      #                                              "袭了上来，一个激凌，丹田立刻变得空空荡荡！\n" NOR)", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "已然放弃抵抗，任凭气流摧袭"
      #                                              "只盼望一切早点结束....\n" NOR)"]}, "damage_formula": %{"formula": "ap * 3 / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap * 3 / 4 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}, {"neili", "-600"}, {"neili", "-800"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}, {"neili", "-600"}, {"neili", "-800"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);", "me->start_busy(4);", "me->start_busy(3 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
      #   - me->start_busy(4);
      #   - me->start_busy(3 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
