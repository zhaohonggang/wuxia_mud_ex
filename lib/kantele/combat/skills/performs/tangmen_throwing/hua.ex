defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.Hua do
  @moduledoc """
  perform「hua」（source tangmen-throwing/hua.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "tangmen-throwing/hua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tangmen-throwing")
    ap = (Stats.skill(stats, "throwing") * 2)
    damage = div((Stats.skill(stats, "throwing") * 2), 3)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 1000}
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 0, 3)
    result = Messages.interpolate("$N手中突然多了一支花，美得妖艳，$n觉得有点痴了，
$N向$n一笑，一扬手向$n抛去。
只见那花开了，五瓣齐舒，中央花心吐蕊，煞是好看。
结果$p一声惨嚎，连中了$P发出的一base_unit。
那花越开越艳，$n不知不觉中已痴迷了，身形一慢,微笑着倒下了，那花也谢了。
$n 身形飘忽，那花划空而过。只听当的一声轻响，那花谢了，轻轻地砸在地面上。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"busy_lines": ["me->start_busy( 2 );", "me->start_busy( 2 );", "me->start_busy( 3 );"], "remote_damage": false}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # string name()
  # {
  #     return(HIR "唐花" NOR);
  # }
  # 
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # int perform( object me, object target )
  # {
  #     int    skill, p;
  #     int    ap, dp, damage;
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
  #          (weapon->query( "id" ) != "tang hua" &&
  #           weapon->query( "skill_type" ) != "throwing") )
  #         return(notify_fail( "你现在手中没有拿着暗器唐花，难以施展" + name() + "。\n" ) );
  # 
  #     if ( (skill = me->query_skill( "tangmen-throwing", 1 ) ) < 180 )
  #         return(notify_fail( "你的唐门暗器不够娴熟，难以施展" + name() + "。\n" ) );
  # 
  # 
  # /*
  #  *      if( me->query("tangmen/yanli")<80 )
  #  *              return notify_fail("你的眼力太差了，目标不精确，无法施展" + name() + "。\n");
  #  */
  #     if ( (int) me->query_skill( "boyun-suowu", 1 ) < 180 )
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
  #     if ( !living( target ) )
  #         return(notify_fail( "对方都已经这样了，用不着这么费力吧？\n" ) );
  # 
  #     me->add( "neili", -100 );
  # 
  #     msg = HIR "\n$N" HIR "手中突然多了一支花，美得妖艳，$n" HIR "觉得有点痴了，\n$N" HIR "向$n" HIR "一笑，一扬手向$n"HIR "抛去。\n" +
  #           HIG "只见那花开了，五瓣齐舒，中央花心吐蕊，煞是好看。\n" NOR;
  # 
  #     ap    = me->query_skill( "throwing" ) * 2;
  #     dp    = target->query_skill( "parry" ) + target->query_skill( "dodge" ) +
  #           target->query_skill( "dugu-jiujian", 1 ) * 10;
  # 
  #     message_combatd( msg, me, target );
  #     tell_object( target, HIC "\n你急忙伸出手去接，但突地，你发现有异，那是一朵铁花，纵身一跃。\n" NOR );
  # /*        if (ap * 2 / 3 + random(ap * 3 / 2) > dp) */
  #     if ( ap / 2 + random( ap ) > dp )
  #     {
  #         if ( target->query( "reborn/times" ) || weapon->query( "id" ) != "tang hua" )
  #         {
  #             string pmsg;
  # 
  #             weapon->add_amount( -1 );
  #             damage    = me->query_skill( "throwing" ) * 2 / 3;
  #             damage    += me->query( "jiali" );
  #             msg    = HIR "结果$p" HIR "一声惨嚎，连中了$P" HIR "发出的一" +
  #                   weapon->query( "base_unit" ) + weapon->name() + HIR "。\n"NOR;
  # 
  #             COMBAT_D->clear_ahinfo();
  #             weapon->hit_ob( me, target, me->query( "jiali" ) + 120 );
  # 
  #             target->receive_damage( "qi", damage, me );
  #             target->receive_wound( "qi", damage, me );
  # 
  #             p = target->query( "qi" ) * 100 / target->query( "max_qi" );
  # 
  #             if ( stringp( pmsg = COMBAT_D->query_ahinfo() ) )
  #                 msg += pmsg;
  # 
  #             msg += "( $n" + eff_status_msg( p ) + " )\n";
  #             message_combatd( msg, me, target );
  #             me->start_busy( 2 );
  #             return(1);
  #         }
  # 
  #         msg = HIR "那花越开越艳，$n" HIR "不知不觉中已痴迷了，身形一慢,微笑着倒下了，那花也谢了。\n" NOR;
  #         tell_object( target, HIR "\n你看到那花，果真是一朵铁花。\n你慢慢的伸出手想摘下它，但"
  #                  "那花好象变的越来越多了，依稀中你记得那上面有一个小小的“唐”字。\n" NOR );
  #         weapon->hit_ob( me, target, me->query( "jiali" ) + 200 );
  #         weapon->move( target );
  # 
  #         message_combatd( msg, me, target );
  #         target->receive_wound( "qi", 100, me );
  #         COMBAT_D->clear_ahinfo();
  #         target->unconcious( me );
  #         me->start_busy( 2 );
  #     } else{
  #         if ( weapon->query( "id" ) == "tang hua" )
  #             tell_object( target, HIR "果真是唐花，唐门中的唐花。你运足全身的内力，身形掠的更急。\n" NOR );
  #         msg = HIR "$n " HIR "身形飘忽，那花划空而过。只听当的一声轻响，那花谢了，轻轻地砸在地面上。\n" NOR;
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
