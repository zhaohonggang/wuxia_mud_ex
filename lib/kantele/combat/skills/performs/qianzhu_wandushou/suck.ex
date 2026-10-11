defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Suck do
  @moduledoc """
  perform「suck」（source qianzhu-wandushou/suck.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "qianzhu-wandushou/suck"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qianzhu-wandushou")
    duli = 7

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.qi < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.qi < 50 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.wound(vitals, :qi, 5)
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"my_force", "xiuluo-yinshagong"}, {"my_skill", "qianzhu-wandushou"}], "busy_lines": ["if( me->is_busy() )", "if( target->is_fighting() || target->is_busy() )"], "remote_damage": false, "resource_gates": [{"age", "99"}, {"neili", "200"}, {"qi", "200"}, {"qi", "50"}], "temp_set": ["nopoison", "wudu_suck"], "var_gates": [{"my_skill", "100"}, {"tg_age", "200"}, {"tg_age", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # inherit F_SSERVER;
  # 
  # int perform(object me,object target)
  # {
  #         // int sp, dp, temp;
  #         int my_skill, my_force, tg_age, skill_count, duli;
  # 
  #         if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/suck"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (environment(me)->query("no_fight"))
  #                 return notify_fail("这里太嘈杂，你不能静下心来修炼。\n");
  # 
  #         if( !objectp(target)
  #         ||  target->query_temp("owner_id") != me->query("id") )
  #                 return notify_fail("你要吸取什么毒虫的毒素？\n");
  # 
  #      /*   if( target->query("age") < 99 )
  #                 return notify_fail("你看清楚点，那东西像是毒虫吗？\n"); */
  #     if( ! target->query("worm_poison") )
  #           return notify_fail("你看清楚点，那东西像是毒虫吗？\n");
  # 
  #         my_skill = (int)me->query_skill("qianzhu-wandushou", 1);
  #         my_force = (int)me->query_skill("xiuluo-yinshagong", 1);
  #         tg_age = (int)target->query("age");
  # 
  #         if( my_skill < 100 )
  #                 return notify_fail("你的千蛛万毒手火候太浅，不能用来吸取毒素！\n");
  # 
  #         if( objectp(me->query_temp("weapon")) )
  #                 return notify_fail("你必须空手才能修炼千蛛万毒手！\n");
  # 
  #         if( me->is_fighting() )
  #                 return notify_fail("战斗中无法修炼千蛛万毒手！\n");
  # 
  #         if( me->is_busy() )
  #                 return notify_fail("你正忙着呢！\n");
  # 
  #         if( target->is_fighting() || target->is_busy() )
  #                 return notify_fail("毒虫正忙着呢，不能和你配合！\n");
  # 
  #         if( me->query_temp("wudu_suck") )
  #                 return notify_fail("你正在修炼中！\n");
  # 
  #         if (! me->can_improve_skill("qianzhu-wandushou"))
  #                 return notify_fail("你的实战经验不够，无法继续修炼千蛛万毒手！\n");
  # 
  # 
  #          if( tg_age - my_skill >= 50 )
  #                 return notify_fail(target->query("name") + "的毒力对你来说太强了，小心把小命送了！\n");
  #          if( my_skill - tg_age >= 50 )
  #                 return notify_fail(target->query("name") + "的毒力对你来说已经太轻微了！\n");
  # 
  #         if( (int)me->query("neili") < 200 )
  #                 return notify_fail("你的内力不够，不足以对抗毒气，别把小命送掉。\n");
  # 
  #         if( (int)target->query("qi") < 50 )
  #                 return notify_fail( target->query("name") + "已经奄奄一息了，你"
  #                                     "无法从他体内吸取任何毒素！\n");
  # 
  #         if( (int)me->query("qi") < 200 )
  #                 return notify_fail( "你快不行了，再练会送命的！\n");
  # 
  #         tell_object(me, RED "你小心翼翼的将手伸到" + target->query("name") +
  #                         RED "的面前，它张嘴就咬住了你的中指。你深吸一口\n气，"
  #                         "面上顿时罩着一股黑气，豆大的汗珠从额头滚了下来。你只"
  #                         "觉得" + target->query("name") + RED "的\n毒素自伤处"
  #                         "源源不绝地流了进来，随真气遍布全身。\n\n" NOR );
  # 
  #         target->receive_wound("qi", 5);
  # 
  #         if( tg_age < 200 )
  #         {
  #                 duli = 3;
  #         }
  # 
  #         if( tg_age > 200 && tg_age < 300)
  #         {
  #                 duli = 5;
  #         }
  # 
  #         if( tg_age > 300 )
  #         {
  #                 duli = 7;
  #         }
  # 
  #         //skill_count = duli * (10 + random((int)me->query_int()));
  #         skill_count = duli * (50 + random((int)me->query_int()));
  #         me->improve_skill("qianzhu-wandushou", skill_count);
  #         me->improve_skill("poison", skill_count);
  #         tell_object(me, HIC "你的「千蛛万毒手」和「基本毒技」熟练度提高了！\n" NOR);
  # 
  #         me->set_temp("wudu_suck", 1);
  #         call_out("del_wudusuck", 3, me, target);
  #         return 1;
  # }
  # 
  # void del_wudusuck(object me,object target)
  # {
  #         if( me->query_temp("wudu_suck") )
  #         {
  #                 me->delete_temp("wudu_suck");
  #                 tell_object(me, RED "\n只见它的肚子越涨越大，“吧嗒”一声，松"
  #                                 "开口掉在了地上。" + target->query("name") + RED
  #                                 "吸饱了鲜\n血，身上透出一层宝光，身子顿时涨大"
  #                                 "了许多！\n\n\n" NOR,);
  #                 me->receive_damage("qi", 20);
  #         }
  # 
  #         target->set_temp("nopoison", 0);
  # }
end
