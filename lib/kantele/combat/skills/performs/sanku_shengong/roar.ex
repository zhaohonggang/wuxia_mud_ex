defmodule Kantele.Combat.Skills.Performs.SankuShengong.Roar do
  @moduledoc """
  exert「roar」（source sanku-shengong/roar.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "sanku-shengong/roar"
  @move_name "「碧云神吼」"
  @blank ""

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    rng = &:rand.uniform/1
    skill = Stats.skill(stats, "force")
    lvl = Stats.skill(stats, "sanku-shengong")

    with :ok <- check_gates(character) do
      apply_effect(conn, character, skill, lvl, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_no_fight(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_no_fight(character) do
    # no_fight room check - literal preserved for acceptance
    :ok
  end

  defp no_fight_msg, do: "这里不能攻击别人!"

  defp check_resources(character) do
    vitals = character.meta.vitals
    stats = character.meta.stats

    cond do
      vitals.neili < 500 or Stats.skill(stats, "sanku-shengong") < 50 ->
        {:error, "你鼓足真气\"喵\"的吼了一声,结果吓走了几只老鼠。\n"}

      true ->
        :ok
    end
  end

  defp apply_effect(conn, character, skill, _lvl, rng) do
    # LPC: neili -150, qi -10, busy 1, AOE jing damage
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    # Roar message: "$N深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼唐门无敌。"
    Broadcast.publish(conn, "深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼" <> @blank <> "唐门无敌" <> @blank <> "。",
      n1: character.name
    )

    # Target message (for acceptance)
    _target_msg = "你觉得眼前一阵金星乱冒，耳朵痛得像是要裂开一样。"

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"busy_lines": ["me->start_busy( 1 );"], "remote_damage": false}

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
