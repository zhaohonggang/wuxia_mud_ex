defmodule Kantele.Combat.Skills.Performs.YujianShu.Yujian do
  @moduledoc """
  perform「yujian」（source yujian-shu/yujian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "sword"}], "level_gates": [{"force", "400"}, {"sword", "400"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "5000"}, {"neili", "150"}, {"neili", "1500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["御剑飞升只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的剑法尚达不到「御剑飞升」的境界。\n", "你的内功火候尚达不到「御剑飞升」的境界。\n", "你的内力修为太弱，无法灵活的御驾内力。\n", "你现在内力不够。\n"], "buff_delete": ["jueji/sword/feisheng"], "callback_functions": [%{"body": "object weapon;
      #           int damage;
      #           string msg;
      #   
      #           if (! target) target = offensive_target(me);
      #   
      #           if (! target || ! me->is_fighting(target))
      #           {
      #                   write(HIW "你运", "name": "perform2", "params": "object me, object target", "return_type": "int"}, %{"body": "if (! me) return;
      #           if (! me->query_temp("jueji/sword/feisheng")) return;
      #           me->delete_temp("jueji/sword/feisheng");
      #           tell_object(me, HIW "\n你经过调气养息，又可以继续使用「"
      #                         ", "name": "end_perform2", "params": "object me", "return_type": "void"}], "color_codes": ["CYN", "HIR", "HIW", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "一声巨喝，聚气入腕，只听破空声一响，手中"
      #                + weapon->name() + HIW "携着隐隐风雷之劲向$n" HIW "澎湃贯"
      #                 "\n出，疾若电闪，势如雷霆。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR", "HIW "\n$N" HIW "手中御剑凌驾如飞，宛若游龙，灵转千变，一道道"
      #                     "凌厉剑气疾射而出。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                              HIR "$n" HIR "看到$N" HIR "这气拔千钧的一击，竟不"
      #                                              "知如何招架，登时受了重创！\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 20,
      #                                              HIR "只听「嗤啦」一声，" HIW "无形剑气" NOR +
      #                                              HIR "竟在$n" HIR "上身刺出一个血洞，数股血柱"
      #                                              "疾射而出！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("sword", 1) +
      #                    (int)me->query_skill("force", 1) +
      #                    (int)me->query_skill("parry", 1) +
      #                    (int)me->query_skill("martial-cognize", 1) / 2"}, "resource_adds": [{"neili", "-100"}, {"neili", "-1000"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-1000"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
