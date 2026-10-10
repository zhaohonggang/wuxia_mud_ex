defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.Qian do
  @moduledoc """
  perform「qian」（source tangmen-throwing/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你现在手中没有拿着暗器心有千千结，难以施展", "你的唐门暗器不够娴熟，难以施展", "你的眼力太差了，目标不精确，无法施展", "你的拨云锁雾不够娴熟，无法施展", "你的内功修为不足，难以施展", "你的内力修为不足，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill( "throwing" )", "dp_formula": "target->query_skill( "dodge" ) +
      #             target->query_skill( "dugu-jiujian", 1 )"}, "callback_functions": [%{"body": "return(HIR "心有千千结" NOR);", "name": "name", "params": "", "return_type": "string"}], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "\n$N" HIR "突然身行一止，从怀中摸出一条" + weapon->name() + HIR "，有无数个结，一扬手向$n " HIR "掷去。\n"
      #             "只见$n" HIR "的周身飞舞着无数的光影，一条天网从空罩下。\n"NOR", "HIR "忽然那无数的光影一闪而没，$n身行一顿，给这" + weapon->name() + HIR "缠上，仰天而倒。\n" NOR", "HIR "$n" HIR "急忙向旁边一纵，躲开着致命的" + weapon->name() + HIR "，但已显得狼狈不堪。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random( ap )", "operator": ">", "right_side": "dp"}, "hit_ob_calls": [{"me", "target", "me->query("jiali") + 200"}], "resource_adds": [{"neili", "-100"}, {"neili", "-1000"}], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if ( !living( target ) || target->is_busy() )", "target->start_busy( ap / 80 + 2 );", "me->start_busy( 3 );"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if ( !living( target ) || target->is_busy() )
      #   - target->start_busy( ap / 80 + 2 );
      #   - me->start_busy( 3 );
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # string name()
      # {
      #     return(HIR "心有千千结" NOR);
      # }
      # 
      # 
      # #include "/kungfu/skill/eff_msg.h";
      # inherit F_SSERVER;
      # 
      # int perform( object me, object target )
      # {
      #     int    skill;
      #     int    ap, dp;
      #     // string    pmsg;
      #     string    msg;
      #     object    weapon;
      # 
      #     if ( !target )
      #         target = offensive_target( me );
      # 
      #     if ( !target || !me->is_fighting( target ) )
      #         return(notify_fail( name() + "只能在战斗中对对手使用。\n" ) );
      # 
      #     if ( !objectp( weapon = me->query_temp( "handing" ) ) ||
      #          (weapon->query( "id" ) != "qianqian jie" &&
      #           weapon->query( "skill_type" ) != "throwing") )
      #         return(notify_fail( "你现在手中没有拿着暗器心有千千结，难以施展" + name() + "。\n" ) );
      # 
      #     if ( (skill = me->query_skill( "tangmen-throwing", 1 ) ) < 140 )
      #         return(notify_fail( "你的唐门暗器不够娴熟，难以施展" + name() + "。\n" ) );
      # 
      # 
      # /*
      #  *      if(  me->query("tangmen/yanli")<80 )
      #  *              return notify_fail("你的眼力太差了，目标不精确，无法施展" + name() + "。\n");
      #  */
      #     if ( (int) me->query_skill( "boyun-suowu", 1 ) < 140 )
      #         return(notify_fail( "你的拨云锁雾不够娴熟，无法施展" + name() + "。\n" ) );
      # 
      #     if ( (int) me->query_skill( "force" ) < 200 )
      #         return(notify_fail( "你的内功修为不足，难以施展" + name() + "。\n" ) );
      # 
      #     if ( me->query( "max_neili" ) < 1200 )
      #         return(notify_fail( "你的内力修为不足，难以施展" + name() + "。\n" ) );
      # 
      #     if ( me->query( "neili" ) < 150 )
      #         return(notify_fail( "你现在真气不足，难以施展" + name() + "。\n" ) );
      # 
      #     if ( !living( target ) || target->is_busy() )
      #         return(notify_fail( "对方都已经这样了，用不着这么费力吧？\n" ) );
      # 
      #     me->add( "neili", -100 );
      # 
      #     msg = HIR "\n$N" HIR "突然身行一止，从怀中摸出一条" + weapon->name() + HIR "，有无数个结，一扬手向$n " HIR "掷去。\n"
      #           "只见$n" HIR "的周身飞舞着无数的光影，一条天网从空罩下。\n"NOR;
      # 
      #     ap    = me->query_skill( "throwing" );
      #     dp    = target->query_skill( "dodge" ) +
      #           target->query_skill( "dugu-jiujian", 1 );
      # 
      #     message_combatd( msg, me, target );
      #     tell_object( target, HIR "\n你急忙屏气凝神，希望能够躲开这致命的" + weapon->name() + HIR "。\n"NOR );
      #     if ( ap / 2 + random( ap ) > dp )
      #     {
      #         msg = HIR "忽然那无数的光影一闪而没，$n身行一顿，给这" + weapon->name() + HIR "缠上，仰天而倒。\n" NOR;
      #         message_combatd( msg, me, target );
      #         tell_object( target, HIR "你只觉得全身被这" + weapon->name() + HIR "越缠越紧，低头一看只见那" + weapon->name() + HIR "已经深深的嵌在你的皮肉中。\n" NOR );
      #         /* weapon->hit_ob(me, target, me->query("jiali") + 200); */
      #         if ( weapon->query( "id" ) != "qianqian jie" )
      #             weapon->add_amount( -1 );
      #         else
      #             weapon->move( target );
      #         target->start_busy( ap / 80 + 2 );
      #     } else{
      #         tell_object( target, HIR "忽然那无数的光影一闪而没，你心中一惊急忙提神运气于足间。\n" NOR );
      #         msg = HIR "$n" HIR "急忙向旁边一纵，躲开着致命的" + weapon->name() + HIR "，但已显得狼狈不堪。\n" NOR;
      #         message_combatd( msg, me, target );
      #         if ( target->query( "neili" ) < 1000 )
      #             target->set( "neili", 0 );
      #         else
      #             target->add( "neili", -1000 );
      #         weapon->move( environment( me ) );
      #         me->start_busy( 3 );
      #     }
      #     return(1);
      # }
end
