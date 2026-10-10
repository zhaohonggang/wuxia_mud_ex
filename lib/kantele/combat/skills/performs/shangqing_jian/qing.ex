defmodule Kantele.Combat.Skills.Performs.ShangqingJian.Qing do
  @moduledoc """
  perform「清流剑」（source shangqing-jian/qing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"damage", "shangqing-jian"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "220"}, {"shangqing-jian", "160"}], "map_gates": [{"sword", "shangqing-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的上清剑法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发上清剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "施出上清剑法「清流剑」绝技，手中" + wname +
      #                 HIG "随即一颤，对准$n" HIG "连攻数剑，招式凌厉无比！\n" NOR", "= CYN "$p" CYN "凝神聚气，硬声声将$P"
      #                          CYN "这一剑架开，丝毫无损。\n" NOR", "= "\n" HIG "却见$N" HIG "跨步上前，手中" + wname +
      #                  HIG "剑招陡变，又攻出一剑，剑尖顿闪出数道剑光，"
      #                  "笼罩$n" HIG "全身！\n" NOR", "= CYN "可是$p" CYN "丝毫不为$P"
      #                          CYN "华丽的剑光所动，稳稳将这一剑架开。\n" NOR", "= "\n" HIG "$N" HIG "随即一声大喝，身外化身，剑外化剑，手中"
      #                  + wname + HIG "顿时漾起一道青芒，再次攻向$n" HIG "而去！\n"
      #                  NOR", "= CYN "$p" CYN "一口气自丹田运了上来，$P"
      #                   CYN "附体剑芒虽然厉害，却未能伤$p" CYN "分毫。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
      #                                              HIR "$p" HIR "奋力抵挡，却哪里招架得住，被$P"
      #                                              HIR "这一剑刺中要脉，鲜血四处飞溅！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                              HIR "$p" HIR "只觉眼花缭乱，一时难以勘透其"
      #                                              "中奥妙，连中数剑，被削得血肉模糊！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #                                              HIR "$p" HIR "运气抵挡，可只觉一股无形剑气"
      #                                              "透体而过，难受之极，喷出数口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("shangqing-jian", 1) / 2"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
