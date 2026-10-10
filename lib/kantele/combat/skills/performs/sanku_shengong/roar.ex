defmodule Kantele.Combat.Skills.Performs.SankuShengong.Roar do
  @moduledoc """
  exert「roar」（source sanku-shengong/roar.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"all_fail_messages": ["这里不能攻击别人! \n", "你鼓足真气\"], "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "damage_formula": %{"formula": "skill - (ob[i]->query( "max_neili" ) ) / 10"}, "resource_adds": [{"neili", "-150"}], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy( 1 );"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy( 1 );
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # /* roar.c 碧云神吼 */
      # 
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # int exert( object me, object target )
      # {
      #     object    *ob;
      #     int    i, skill, damage;
      # 
      #     if ( environment( me )->query( "no_fight" ) )
      #         return(notify_fail( "这里不能攻击别人! \n" ) );
      # 
      #     if ( (me->query( "neili" ) < 500) || me->query_skill( "sanku-shengong", 1 ) < 50 )
      #         return(notify_fail( "你鼓足真气\"喵\"的吼了一声, 结果吓走了几只老鼠。\n" ) );
      # 
      #     skill = me->query_skill( "force" );
      # 
      #     me->add( "neili", -150 );
      #     me->receive_damage( "qi", 10 );
      # 
      #     me->start_busy( 1 );
      #     message_combatd(
      #         HIY "$N深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼" + HIR "唐门无敌" NOR + "。\n" NOR, me );
      # 
      #     ob = all_inventory( environment( me ) );
      #     for ( i = 0; i < sizeof(ob); i++ )
      #     {
      #         if ( !ob[i]->is_character() || ob[i] == me )
      #             continue;
      # 
      #         if ( skill / 2 + random( skill / 2 ) < (int) ob[i]->query_con() * 2 )
      #             continue;
      # 
      #         if ( userp( ob[i] ) && !ob[i]->die_protect( me ) )
      #             continue;
      # 
      #         me->want_kill( ob[i] );
      #         me->fight_ob( ob[i] );
      #         ob[i]->kill_ob( me );
      # 
      #         damage = skill - (ob[i]->query( "max_neili" ) ) / 10;
      #         if ( damage > 0 )
      #         {
      #             ob[i]->set( "last_damage_from", me );
      #             ob[i]->receive_damage( "jing", damage * 2, me );
      #             if ( ob[i]->query( "neili" ) < skill * 2 )
      #                 ob[i]->receive_wound( "jing", damage, me );
      #             tell_object( ob[i], "你觉得眼前一阵金星乱冒，耳朵痛得像是要裂开一样。\n" );
      #         }
      #     }
      # 
      #     return(1);
      # }
end
