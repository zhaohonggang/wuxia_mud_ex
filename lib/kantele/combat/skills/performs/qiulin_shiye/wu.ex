defmodule Kantele.Combat.Skills.Performs.QiulinShiye.Wu do
  @moduledoc """
  随风而舞「wu」（对照 `kungfu/skill/qiulin-shiye/wu.c`）

  秋林师业脱身绝技：需 qiulin-shiye>=90、真气>=500、自身未忙乱。
  命中判定 `random(自身combat_exp/100) > 目标combat_exp/400`：命中后目标若未忙
  则忙乱 `4 + random(4)` 轮；攻击方恒扣 200 真气、忙乱 1，并自伤
  qi 200 / jing 80（LPC 为 `receive_damage`）。

  差异（TODO(migrate)）：
  - LPC 命中分支末段 `me->move(exits[random])`（随机逃向相邻房间）本引擎无处可建模，
    已略去；该分支的 `receive_damage("qi",200)/("jing",80)` 只能在攻击方侧落账，
    故本版无条件施加（文档化偏差）；
  - `.c` 无 `living(target)` 门槛，目标已死由 `combat/perform-incoming` 统一短路。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "qiulin-shiye/wu"
  @move_name "随风而舞"

  # LPC: string name() { return("随风而舞"); }
  def name, do: "随风而舞"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- check_target(combat),
         :ok <- check_level(stats),
         :ok <- check_neili(character),
         :ok <- check_not_busy(character) do
      apply_perform(conn, character, target, stats, combat)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || ! target->is_character() || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能在战斗中使用「#{@move_name}」。\n"}
    end
  end

  # LPC: if ((int) me->query_skill("qiulin-shiye", 1) < 90)
  defp check_level(stats) do
    if Stats.skill(stats, "qiulin-shiye") < 90 do
      {:error, "你目前功力还使不出「#{@move_name}」。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 500)
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->is_busy())
  defp check_not_busy(character) do
    if character.meta.combat.busy > 0 do
      {:error, "你现在正忙着呢。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, stats, combat) do
    # LPC: me->add("neili", -200); me->start_busy(1);
    #      命中分支另有 me->receive_damage("qi", 200) / ("jing", 80)（见 moduledoc 偏差说明）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 200, 0)}
    vitals = vitals |> Vitals.damage(:qi, 200) |> Vitals.damage(:jing, 80)
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: msg = HIC "$N突然轻嘘一声，身形一展，向随风飘舞而上，身形越来越小。\n"NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N突然轻嘘一声，身形一展，向随风飘舞而上，身形越来越小。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        combat_exp: stats.combat_exp || 0,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    do_resolve_incoming(conn, character, attacker, data)
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp") / 100) > target->query("combat_exp") / 400)
    my_exp = max(div(Map.get(data, :combat_exp, 0), 100), 1)
    ob_exp = div(stats.combat_exp || 0, 400)

    if Engine.rand(rng, my_exp) > ob_exp do
      # LPC: if (! target->is_busy()) target->start_busy(4 + random(4));
      combat =
        if character.meta.combat.busy <= 0 do
          Combat.start_busy(character.meta.combat, 4 + Engine.rand(rng, 4))
        else
          character.meta.combat
        end

      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: msg += RED "只见$n只看的目瞪口呆,一时手忙脚乱起来，不知如何是好。\n"NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "只见$n只看的目瞪口呆,一时手忙脚乱起来，不知如何是好。\n",
            bindings
          )
        )

      put_character(conn, character)
    else
      # LPC: msg += HIC "可是$p却暴身南而起，大喝一声：“那里走！”，拦在你的前面，$P这招没有得逞。\n" NOR;
      Broadcast.publish(
        conn,
        Messages.interpolate(
          "可是$p却暴身南而起，大喝一声：“那里走！”，拦在你的前面，$P这招没有得逞。\n",
          bindings
        )
      )
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "qiulin-shiye/wu",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # string name()
  # {
  #     return("随风而舞");
  # }
  # 
  # int perform( object me, object target )
  # {
  #     string    msg;
  #     object    env        = environment( me );
  #     mapping exits    = env->query( "exits" );
  #     string    *obb;
  # 
  #     if ( !target )
  #         target = offensive_target( me );
  # 
  #     if ( !target || !target->is_character() ||
  #          !me->is_fighting( target ) )
  #         return(notify_fail( "你只能在战斗中使用「随风而舞」。\n" ) );
  # 
  #     if ( (int) me->query_skill( "qiulin-shiye", 1 ) < 90 )
  #         return(notify_fail( "你目前功力还使不出「随风而舞」。\n" ) );
  # 
  #     if ( me->query( "neili" ) < 500 )
  #         return(notify_fail( "你的内力不够。\n" ) );
  # 
  #     if ( me->is_busy() )
  #         return(notify_fail( "你现在正忙着呢。\n" ) );
  # 
  #     me->add( "neili", -200 );
  #     msg = HIC "$N突然轻嘘一声，身形一展，向随风飘舞而上，身形越来越小。\n"NOR;
  #     me->start_busy( 1 );
  # 
  #     if ( random( me->query( "combat_exp" ) / 100 ) >
  #          target->query( "combat_exp" ) / 400 )
  #     {
  #         if ( !target->is_busy() )
  #             target->start_busy( 4 + random( 4 ) );
  #         me->receive_damage( "qi", 200 );
  #         me->receive_damage( "jing", 80 );
  #         msg += RED "只见$n只看的目瞪口呆,一时手忙脚乱起来，不知如何是好。\n"NOR;
  #         message_combatd( msg, me, target );
  #         if ( sizeof(exits) > 0 )
  #         {
  #             obb = values( exits );
  #             me->move( obb[random( sizeof(obb) )] );
  #         }
  #     } else{
  #         msg += HIC "可是$p却暴身南而起，大喝一声：“那里走！”，拦在你的前面，$P这招没有得逞。\n" NOR;
  #         message_combatd( msg, me, target );
  #     }
  #     return(1);
  # }
end
