defmodule Kantele.Combat.Skills.Performs.Force.Roar do
  @moduledoc """
  exert「roar」（source force/roar.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "force"}], "level_gates": [], "map_gates": [{"force", "huntian-qigong"}, {"force", "hunyuan-gong"}, {"force", "jiuyang-shengong"}, {"force", "jiuyin-shengong"}, {"force", "kuihua-mogong"}, {"force", "longxiang-gong"}, {"force", "tianhuan-shenjue"}, {"force", "xixing-dafa"}, {"force", "yijinjing"}, {"force", "zhanshen-xinjing"}], "prepared_gates": [], "resource_gates": [{"eff_jing", "1"}, {"jing", "1"}, {"neili", "800"}], "var_gates": [{"skill", "180"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你的内功修为不够。\n", "在这里不能攻击他人。\n", "在这里不能攻击他人。\n", "你的真气不够。\n"], "color_codes": ["HIR", "HIW", "HIY", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "运转真气，面无表情，歌声如梵唱般"
      #                         "贯入众人耳中。\n" NOR", "HIY "$N" HIY "深深吸入一囗气，运足内力发出一阵"
      #                         "长啸，音传百里，慑人心神。\n" NOR", "HIY "$N" HIY "仰天长啸，声音绵泊不绝，众人无不"
      #                         "听得心驰神摇。\n" NOR", "HIY "$N" HIY "气凝丹田，猛然一声断喝，声音远远"
      #                         "的传了开去，激荡不止。\n" NOR", "HIY "$N" HIY "蓦地极嘶长呼，声音凄厉之极，令人"
      #                         "毛骨悚然。\n" NOR", "HIY "$N" HIY "深深吸入一囗气，运起金刚禅狮子吼"
      #                         "，发出惊天动地的一声巨吼。\n" NOR", "HIY "$N" HIY "深深吸入一囗气，体内" + to_chinese(f) +
      #                         HIY "真气急剧迸发，陡然一声巨啸。\n" NOR", "= "\n"", "WHT "突然只见" + ob[i]->name() + WHT "两手"
      #                                         "抱头，双目凸出，嘴角泛出些许白沫，喉咙咯咯"
      #                                         "作响。\n" NOR", "WHT "顿时听得" + ob[i]->name() + WHT "一声"
      #                                         "惨叫，两眼发直，全身不住颤抖，蓦地呕出一口"
      #                                         "鲜血。\n" NOR", "WHT "却见" + ob[i]->name() + WHT "竟摔倒在"
      #                                         "地，发出声声哀嚎，双目双耳及鼻孔均渗出丝丝"
      #                                         "鲜血。\n" NOR"], "success": []}, "damage_formula": %{"formula": "skill - ((int)ob[i]->query("max_neili") / 10)"}, "receive_damage_calls": [%{"formula": "damage * 2", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"jing", "10"}, {"neili", "-800"}], "resource_queries": ["jing", "max_neili", "neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"eff_jing", "10"}, {"jing", "10"}, {"neili", "-800"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(5);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(5);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // roar.c
      # // By Vin for heros.cn
      # 
      # #include <ansi.h>
      # inherit F_CLEAN_UP;
      # 
      # int exert(object me, object target)
      # {
      #         object *ob;
      #         int f, i, skill, damage;
      #         string msg;
      # 
      #         f = me->query_skill_mapped("force");
      #         skill = me->query_skill("force");
      # 
      #         if (me->query_skill_mapped("force") != "longxiang-gong"
      #            && me->query_skill_mapped("force") != "tianhuan-shenjue"
      #            && me->query_skill_mapped("force") != "huntian-qigong"
      #            && me->query_skill_mapped("force") != "jiuyang-shengong"
      #            && me->query_skill_mapped("force") != "jiuyin-shengong"
      #            && me->query_skill_mapped("force") != "kuihua-mogong"
      #            && me->query_skill_mapped("force") != "xixing-dafa"
      #            && me->query_skill_mapped("force") != "zhanshen-xinjing"
      #            && me->query_skill_mapped("force") != "yijinjing"
      #            && me->query_skill_mapped("force") != "hunyuan-gong")
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         if (skill < 180)
      #                 return notify_fail("你的内功修为不够。\n");
      # 
      #         if (environment(me)->query("no_fight"))
      #                 return notify_fail("在这里不能攻击他人。\n");
      # 
      #         // 执行天书任务的特殊房间防止龙吟中断剧情。
      #         if (environment(me)->query("skybook"))
      #                 return notify_fail("在这里不能攻击他人。\n");
      # 
      #         if ((int)me->query("neili") < 800)
      #                 return notify_fail("你的真气不够。\n");
      # 
      #         me->add("neili", -800);
      # 
      #         me->start_busy(5);
      # 
      #         switch (f)
      #         {
      #         case "longxiang-gong" :
      #                 msg = HIW "$N" HIW "运转真气，面无表情，歌声如梵唱般"
      #                       "贯入众人耳中。\n" NOR;
      #                 break;
      # 
      #         case "huntian-qigong" :
      #                 msg = HIY "$N" HIY "深深吸入一囗气，运足内力发出一阵"
      #                       "长啸，音传百里，慑人心神。\n" NOR;
      #                 break;
      # 
      #         case "jiuyang-shengong" :
      #                 msg = HIY "$N" HIY "仰天长啸，声音绵泊不绝，众人无不"
      #                       "听得心驰神摇。\n" NOR;
      #                 break;
      # 
      #         case "jiuyin-shengong" :
      #                 msg = HIY "$N" HIY "气凝丹田，猛然一声断喝，声音远远"
      #                       "的传了开去，激荡不止。\n" NOR;
      #                 break;
      # 
      #         case "kuihua-mogong" :
      #                 msg = HIY "$N" HIY "蓦地极嘶长呼，声音凄厉之极，令人"
      #                       "毛骨悚然。\n" NOR;
      #                 break;
      # 
      #         case "yijinjing" :
      #         case "hunyuan-gong" :
      #                 msg = HIY "$N" HIY "深深吸入一囗气，运起金刚禅狮子吼"
      #                       "，发出惊天动地的一声巨吼。\n" NOR;
      #                 break;
      # 
      #         default:
      #                 msg = HIY "$N" HIY "深深吸入一囗气，体内" + to_chinese(f) +
      #                       HIY "真气急剧迸发，陡然一声巨啸。\n" NOR;
      #                 break;
      #         }
      #         msg += "\n";
      #         message_combatd(msg, me);
      # 
      #         ob = all_inventory(environment(me));
      # 
      #         for (i = 0; i < sizeof(ob); i++)
      #         {
      # 
      #                 if (! living(ob[i]) || ob[i] == me)
      #                         continue;
      # 
      #                 if (skill / 2 + random(skill / 2) < (int)ob[i]->query("con") * 2)
      #                         continue;
      # 
      #                 // 被死亡保护的玩家不受伤害
      #                 if ((int)ob[i]->query_condition("die_guard"))
      #                         continue;
      # 
      #                 damage = skill - ((int)ob[i]->query("max_neili") / 10);
      # 
      #                 if (damage > 0)
      #                 {
      #                         ob[i]->receive_damage("jing", damage * 2, me);
      # 
      #                         if ((int)ob[i]->query("neili") < skill * 2)
      #                                 ob[i]->receive_wound("jing", damage, me);
      # 
      #                         tell_object(ob[i], HIR "突然间你只觉两耳一阵轰鸣，眼前金"
      #                                            "星乱冒，整个头便是要裂开一般。\n" NOR);
      # 
      #                         switch (random(3))
      #                 {
      #                 case 0 :
      #                         msg = WHT "突然只见" + ob[i]->name() + WHT "两手"
      #                                       "抱头，双目凸出，嘴角泛出些许白沫，喉咙咯咯"
      #                                       "作响。\n" NOR;
      #                         break;
      # 
      #                 case 1 :
      #                         msg = WHT "顿时听得" + ob[i]->name() + WHT "一声"
      #                                       "惨叫，两眼发直，全身不住颤抖，蓦地呕出一口"
      #                                       "鲜血。\n" NOR;
      #                         break;
      # 
      #                 default :
      #                         msg = WHT "却见" + ob[i]->name() + WHT "竟摔倒在"
      #                                       "地，发出声声哀嚎，双目双耳及鼻孔均渗出丝丝"
      #                                       "鲜血。\n" NOR;
      #                         break;
      #                 }
      #                         message("vision", msg, environment(ob[i]), ({ob[i]}));
      # 
      #                         if ((int)ob[i]->query("jing") < 1
      #                            || (int)ob[i]->query("eff_jing") < 1)
      #                                 ob[i]->unconcious(me);
      # 
      #                         if (objectp(ob[i]) && ! living(ob[i]))
      #                         {
      #                                 ob[i]->add("jing", 10);
      #                                 ob[i]->add("eff_jing", 10);
      #                         }
      #                 }
      #                 me->want_kill(ob[i]);
      #                 me->fight_ob(ob[i]);
      #                 ob[i]->kill_ob(me);
      #         }
      #         return 1;
      # }
end
