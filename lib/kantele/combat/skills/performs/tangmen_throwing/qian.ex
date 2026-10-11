defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.Qian do
  @moduledoc """
  perform「qian」（source tangmen-throwing/qian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tangmen-throwing/qian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tangmen-throwing")
    ap = Stats.skill(stats, "throwing")

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
    result = Messages.interpolate("$N突然身行一止，从怀中摸出一条，有无数个结，一扬手向$n 掷去。
只见$n的周身飞舞着无数的光影，一条天网从空罩下。
忽然那无数的光影一闪而没，$n身行一顿，给这缠上，仰天而倒。
$n急忙向旁边一纵，躲开着致命的，但已显得狼狈不堪。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"busy_lines": ["if ( !living( target ) || target->is_busy() )", "target->start_busy( ap / 80 + 2 );", "me->start_busy( 3 );"], "remote_damage": false}

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
