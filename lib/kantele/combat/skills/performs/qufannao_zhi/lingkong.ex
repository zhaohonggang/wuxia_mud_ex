defmodule Kantele.Combat.Skills.Performs.QufannaoZhi.Lingkong do
  @moduledoc """
  perform「凌空指穴」（source qufannao-zhi/lingkong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"damage", "qufannao-zhi"}, {"dp", "force"}], "level_gates": [{"hunyuan-yiqi", "100"}, {"qufannao-zhi", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "100"}, {"damage", "300"}, {"damage", "500"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的去烦恼指不够娴熟，不会使用", "你的心意气混元功不够高，不能用内力催动指力伤敌。\n", "你现在内力太弱，不能使用"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force", 1) + me->query_skill("finger", 1) + 
      #                me->query_skill("qufannao-zhi", 1) + me->query("neili", 1) / 50", "dp_formula": "target->query_skill("force", 1) + target->query_skill("dodge", 1) +
      #                target->query_skill("parry", 1)"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["CYN "$N默念佛经，只见手指微动，几道指气急射向$n，意欲以指力击晕$n。\n"NOR", "= HIY "$n受到$N的指力透击，闷哼一声，看上去很是疲惫。\n" NOR", "= HIY "$n被$N的指力反击，只觉得胸中烦闷，只想好好休息休息。\n" NOR", "= RED "$n被$N以指力一震，脑中嗡嗡作响，意识开始模糊起来！\n" NOR", "= CYN "可是$p看破了$P的企图，并没有上当。\n" NOR"], "success": ["= HIR "$n被$N的指力一震，眼前一黑，向后便倒，眼看就要不醒人事了！\n" NOR"]}, "damage_formula": %{"formula": "(int)me->query_skill("qufannao-zhi", 1)"}, "hit_formula": %{"left_side": "random(ap) + random(ap / 3)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": None}, %{"formula": "damage / 6", "kind": "wound", "part": "qi", "source": None}], "resource_adds": [{"neili", "-damage / 6"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(4);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(random(3));
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // lingkong
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define LING "「" HIW "凌空指穴" NOR "」" 
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         //if (userp(me) && ! me->query("can_perform/qufannao-zhi/lingkong"))   
      #         //        return notify_fail("你所使用的外功中没有这种功能。\n");   
      # 
      #         if( !target ) target = offensive_target(me);
      # 
      #         if( !target || !target->is_character() || !me->is_fighting(target) )
      #                 return notify_fail(LING "只能对战斗中的对手使用。\n");
      # 
      #         if( objectp(me->query_temp("weapon")) )
      #                 return notify_fail("你必须空手才能使用" LING "！\n");           
      # 
      #         if( (int)me->query_skill("qufannao-zhi", 1) < 100 )
      #                 return notify_fail("你的去烦恼指不够娴熟，不会使用" LING "。\n");
      # 
      #         if( (int)me->query_skill("hunyuan-yiqi", 1) < 100 )
      #                 return notify_fail("你的心意气混元功不够高，不能用内力催动指力伤敌。\n");
      # 
      #         if( (int)me->query("neili", 1) < 300 )
      #                 return notify_fail("你现在内力太弱，不能使用" LING "。\n");
      # 
      #         msg = CYN "$N默念佛经，只见手指微动，几道指气急射向$n，意欲以指力击晕$n。\n"NOR;
      # 
      #         ap = me->query_skill("force", 1) + me->query_skill("finger", 1) + 
      #              me->query_skill("qufannao-zhi", 1) + me->query("neili", 1) / 50;
      #         dp = target->query_skill("force", 1) + target->query_skill("dodge", 1) +
      #              target->query_skill("parry", 1);
      #         if (random(ap) + random(ap / 3) > dp )
      #         {
      #                 me->start_busy(3);
      #                 target->start_busy(random(3));
      #                 
      #                 damage = (int)me->query_skill("qufannao-zhi", 1);
      #                 
      #                 damage = damage / 2 + random(damage);
      #                 
      #                 target->receive_damage("qi", damage);
      #                 target->receive_wound("qi", damage / 6);
      #                 me->add("neili", -damage / 6);
      #                 
      #                 if( damage < 100 )
      #                         msg += HIY "$n受到$N的指力透击，闷哼一声，看上去很是疲惫。\n" NOR;
      #                 
      #                 else if( damage < 300 )
      #                         msg += HIY "$n被$N的指力反击，只觉得胸中烦闷，只想好好休息休息。\n" NOR;
      #         
      #                 else if( damage < 500 )
      #                         msg += RED "$n被$N以指力一震，脑中嗡嗡作响，意识开始模糊起来！\n" NOR;
      #                 else
      #                         msg += HIR "$n被$N的指力一震，眼前一黑，向后便倒，眼看就要不醒人事了！\n" NOR;
      #                 
      #         }
      #         else 
      #         {
      #                 me->start_busy(4);
      #                 msg += CYN "可是$p看破了$P的企图，并没有上当。\n" NOR;
      #         }
      #         message_vision(msg, me, target);
      # 
      #         return 1;
      # }
end
