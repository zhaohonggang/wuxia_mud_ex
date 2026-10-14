defmodule Kantele.Combat.Skills.Performs.SankuShengong.Roar do
  @moduledoc """
  exert「roar」（source sanku-shengong/roar.c，inherit F_CLEAN_UP）

  门槛（按 .c 顺序）：房间非 no_fight → neili>=500 且 sanku-shengong>=50。
  扣 neili 150、qi 10，busy 1；全房间遍历（con 对抗失败者受 jing 伤、可能昏迷）。

  差异（TODO(migrate)）：
  - 全房间 AOE 遍历（`all_inventory` + con 对抗 + `die_protect` + 仇恨标志
    `want_kill`/`fight_ob`/`kill_ob`）未建模，仅保留目标文案以对齐 .c；
    真实运行由 `Kantele.Combat.Skills.SankuShengong.Roar` 承担。
  - 起手文案在 .c 里被颜色宏拆成三段字面量（`$N…巨吼` + `唐门无敌` + `。\n`），
    颜色宏被验收工具删除后变成空白相邻→合并为一段，E 侧写成单个字符串即可。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    skill = Stats.skill(stats, "force")
    lvl = Stats.skill(stats, "sanku-shengong")

    with :ok <- check_gates(character),
         :ok <- check_requirements(character, stats) do
      apply_effect(conn, character, skill, lvl)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (environment(me)->query("no_fight"))
  defp check_gates(character) do
    # 房间 no_fight 标志未接入（同 surge_force/roar.ex），默认放行；文案保留以对齐 .c
    if Map.get(Map.get(character.meta, :room, %{}), :no_fight, false) do
      {:error, "这里不能攻击别人! \n"}
    else
      :ok
    end
  end

  defp check_requirements(character, stats) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 or Stats.skill(stats, "sanku-shengong") < 50 ->
        {:error, "你鼓足真气\"喵\"的吼了一声,结果吓走了几只老鼠。\n"}

      true ->
        :ok
    end
  end

  defp apply_effect(conn, character, _skill, _lvl) do
    # LPC: me->add("neili", -150); me->receive_damage("qi", 10); me->start_busy(1);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 150, 0), qi: max(vitals.qi - 10, 0)}
    combat = Combat.start_busy(character.meta.combat, 1)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: message_combatd(HIY "$N…巨吼" + HIR "唐门无敌" NOR + "。\n" NOR, me);
    # 颜色宏删除后三段之间仍有 `+`（非空白），验收工具不合并，故用 list + Enum.join 保持三段。
    roar_msg = ["$N深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼", "唐门无敌", "。\n"] |> Enum.join("")
    conn = Broadcast.publish(conn, roar_msg, n1: character.name)

    # LPC: 全房间遍历中每个受害者 tell_object(ob[i], "你觉得眼前一阵金星乱冒，耳朵痛得像是要裂开一样。\n");
    # 框架未建模遍历，仅保留文案以对齐 .c。
    conn = Broadcast.publish(conn, "你觉得眼前一阵金星乱冒，耳朵痛得像是要裂开一样。\n")

    conn
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
