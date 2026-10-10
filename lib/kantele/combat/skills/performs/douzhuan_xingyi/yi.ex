defmodule Kantele.Combat.Skills.Performs.DouzhuanXingyi.Yi do
  @moduledoc """
  perform「yi」（source douzhuan-xingyi/yi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "douzhuan-xingyi"}, {"dp", "force"}], "level_gates": [{"douzhuan-xingyi", "100"}, {"zihui-xinfa", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "60"}], "var_gates": [{"i", "2"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还不会使用斗转星移。\n", "「斗转星移」只能对战斗中的对手使用。\n", "你的斗转星移不够娴熟，不会使用绝招。\n", "你的紫徽心法修为还不到家，", "你现在真气不够，无法使用「斗转星移」。\n", "对方都已经这样了，用不着这么费力吧？\n", "对方手里拿的是一根小小的针，"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("douzhuan-xingyi", 1) +
      #                me->query_skill("zihui-xinfa", 1) / 2", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIC", "HIG", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "运起紫徽心法，内力自气海穴出，经由"
      #                 "任督二脉奔流而出，巧妙的牵引着$n" HIM "的招式！\n"", "= CYN "然而$p" CYN "内功深厚，并没有被$P"
      #                          CYN "这巧妙的劲力所带动。\n" CYN", "= HIC "结果$p" HIC "的招式莫名其妙的变"
      #                          "了方向，竟然控制不住！幸好身边没有别"
      #                          "人，没有酿成大祸。\n" NOR", "= HIG "结果$p" HIG "发出的招式不由自主"
      #                          "的变了方向，突然攻向" + name + HIG "，不禁令" +
      #                          name + HIG "大吃一惊，招架不迭！" NOR"], "success": ["= HIR "结果$p" HIR "一招击出，正好打在自己的"
      #                          "要害上，不禁一声惨叫，摔跌开去。\n" NOR"]}, "damage_formula": %{"formula": "target->query("max_qi")"}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": "<", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 2", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 2", "kind": "wound", "part": "qi", "source": "me"}], "resource_adds": [{"neili", "-50"}], "resource_queries": ["max_qi", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_forbidden": ["pin"]}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "if (! der->is_busy()) der->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - if (! der->is_busy()) der->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // yi.c 斗转星移
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         object *obs;
      #         object der;
      #     string msg;
      #         int ap, dp;
      #         int damage;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/douzhuan-xingyi/yi"))
      #                 return notify_fail("你还不会使用斗转星移。\n");
      # 
      #         me->clean_up_enemy();
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("「斗转星移」只能对战斗中的对手使用。\n");
      # 
      #     if ((int)me->query_skill("douzhuan-xingyi", 1) < 100)
      #         return notify_fail("你的斗转星移不够娴熟，不会使用绝招。\n");
      # 
      #         if ((int)me->query_skill("zihui-xinfa", 1) < 100)
      #                 return notify_fail("你的紫徽心法修为还不到家，"
      #                                    "难以运用「斗转星移」。\n");
      # 
      #         if (me->query("neili") < 60)
      #                 return notify_fail("你现在真气不够，无法使用「斗转星移」。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     weapon = target->query_temp("weapon");
      #         if (weapon && weapon->query("skill_type") == "pin")
      #                 return notify_fail("对方手里拿的是一根小小的针，"
      #                                    "你没有办法施展「斗转星移」。\n");
      # 
      #     msg = HIM "$N" HIM "运起紫徽心法，内力自气海穴出，经由"
      #               "任督二脉奔流而出，巧妙的牵引着$n" HIM "的招式！\n";
      # 
      #         ap = me->query_skill("douzhuan-xingyi", 1) +
      #              me->query_skill("zihui-xinfa", 1) / 2;
      #         dp = target->query_skill("force");
      #         der = 0;
      #         me->start_busy(2);
      #         me->add("neili", -50);
      #         if (ap > dp * 13 / 10)
      #         {
      #                 // Success to make the target attack hiself
      #                 msg += HIR "结果$p" HIR "一招击出，正好打在自己的"
      #                        "要害上，不禁一声惨叫，摔跌开去。\n" NOR;
      #                 damage = target->query("max_qi");
      #                 target->receive_damage("qi", damage / 2, me);
      #                 target->receive_wound("qi", damage / 2, me);
      #         } else
      #         if (ap / 3 + random(ap) < dp)
      #         {
      #                 // The enemy has defense
      #                 msg += CYN "然而$p" CYN "内功深厚，并没有被$P"
      #                        CYN "这巧妙的劲力所带动。\n" CYN;
      #         } else
      #         if (sizeof(obs = me->query_enemy() - ({ target })) == 0)
      #         {
      #                 // No other enemy
      #                 msg += HIC "结果$p" HIC "的招式莫名其妙的变"
      #                        "了方向，竟然控制不住！幸好身边没有别"
      #                        "人，没有酿成大祸。\n" NOR;
      #         } else
      #         {
      #                 string name;
      #                 // Sucess to make the target attack my enemy
      #                 der = obs[random(sizeof(obs))];
      #                 name = der->name();
      #                 if (name == target->name()) name = "另一个" + name;
      #                 msg += HIG "结果$p" HIG "发出的招式不由自主"
      #                        "的变了方向，突然攻向" + name + HIG "，不禁令" +
      #                        name + HIG "大吃一惊，招架不迭！" NOR;
      #         }
      # 
      #     message_combatd(msg, me, target);
      # 
      #         if (der)
      #         {
      #                 // Target attack my enemy
      #                 for (i = 0; i < 2 + random(3); i++)
      #                 {
      #                         if (! der->is_busy()) der->start_busy(1);
      #                         COMBAT_D->do_attack(target, der, target->query_temp("weapon"));
      #                 }
      #         }
      # 
      #     return 1;
      # }
end
