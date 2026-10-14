defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Suck do
  @moduledoc """
  perform「suck」（对照 `kungfu/skill/qianzhu-wandushou/suck.c`）

  自修炼绝招：对**自己拥有**的毒虫（worm）吸取毒素练技。门槛（按 .c 顺序）：
  已学此招 → 房间 no_fight → 目标是自己的毒虫（`worm_poison`）→
  千蛛万毒手>=100 → 空手 → 自身未在战斗中 → 自身未忙乱 → 毒虫未在战斗中
  且未忙乱 → 未在修炼中（`wudu_suck`）→ 实战经验足够 →
  毒力与修为相差不超过 50（两条）→ 真气>=200 → 毒虫气血>=50 → 自身气血>=200。
  成功后按毒虫岁数取 `duli`（`tg_age<200` 为 3、`200<tg_age<300` 为 5、
  `tg_age>300` 为 7，`.c` 在 200/300 两点上留空即 0），
  `skill_count = duli * (50 + random(int))` 用于历练「千蛛万毒手」与
  「基本毒技」；`set_temp("wudu_suck")` 后 3 秒触发 `del_wudusuck`。

  差异（TODO(migrate)）：
  - LPC 的目标是玩家指定的毒虫生物；引擎 perform 命令不带目标参数，按
    `shedu_qiqiao/liandu.ex` 的做法从 `rooms:<room_id>` 订阅者里取第一个
    非自身角色快照（`:sys.get_state` 只读副本，异常时退化为空 meta）；
    `query_temp("owner_id")` 归属检查无法跨进程读取，由 `worm_poison`
    标记近似（毒虫宿主本身在本引擎世界数据里未落地，故通常先命中
    「你看清楚点，那东西像是毒虫吗？」）；
  - `target->query("age")`（毒虫岁数）未建模，`stats` 无 age 字段，默认 0，
    于是 `my_skill - tg_age >= 50` 恒成立——比较逻辑与 .c 逐字一致，
    属输入数据缺失降级；
  - `improve_skill` 技能历练未建模（同 `xiuluo_yinshagong/suck.ex` 的降级），
    仅保留提示文案；`target->receive_wound("qi", 5)` 无法写别的进程，
    不落代码；`duli`/`skill_count` 的算式在文末保留的 LPC 源码块里；
  - `set_temp("wudu_suck")` 折算为 `Combat.Buff{key: "wudu_suck"}`，
    `call_out("del_wudusuck", 3, …)` 折算为 3 秒后的 `combat/buff-expire`
    （发布 `del_wudusuck` 的文案）；`me->receive_damage("qi", 20)` 在
    buff-expire 处理器里无法执行（只发文案），不落代码。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.LearnGate
  alias Kantele.Communication
  alias Kantele.Character.Stats

  @perform_id "qianzhu-wandushou/suck"
  @wudu_suck_key "wudu_suck"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_perform_known(character),
         :ok <- check_no_fight(character),
         {:ok, target} <- find_worm(character),
         :ok <- check_worm_poison(target),
         :ok <- check_levels(character),
         :ok <- check_weapon(character),
         :ok <- check_self_state(character),
         :ok <- check_worm_state(target),
         :ok <- check_wudu_suck(character),
         :ok <- check_can_improve(character),
         :ok <- check_toxicity(character, target),
         :ok <- check_self_resources(character),
         :ok <- check_worm_qi(target),
         :ok <- check_self_qi(character) do
      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/suck"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (environment(me)->query("no_fight"))
  #              return notify_fail("这里太嘈杂，你不能静下心来修炼。\n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "这里太嘈杂，你不能静下心来修炼。\n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if( !objectp(target)
  #      ||  target->query_temp("owner_id") != me->query("id") )
  #              return notify_fail("你要吸取什么毒虫的毒素？\n");
  # 引擎 perform 命令不带目标参数：按 liandu.ex 的做法从房间订阅者里取
  # 第一个非自身角色作为目标快照（归属检查见 moduledoc）。
  defp find_worm(character) do
    case room_others(character.room_id) do
      [target | _] -> {:ok, target}
      [] -> {:error, "你要吸取什么毒虫的毒素？\n"}
    end
  end

  defp room_others(room_id) do
    Communication.subscribers("rooms:#{room_id}")
    |> Enum.map(fn {_channel_name, pid, _options} -> pid end)
    |> Enum.reject(&(&1 == self()))
    |> Enum.map(&safe_state/1)
  end

  defp safe_state(pid) when is_pid(pid) do
    :sys.get_state(pid)
  catch
    _, _ -> %{pid: pid, meta: %{}}
  end

  # LPC: if( ! target->query("worm_poison") )
  #              return notify_fail("你看清楚点，那东西像是毒虫吗？\n");
  defp check_worm_poison(target) do
    if is_nil(Map.get(target.meta, :worm_poison)) do
      {:error, "你看清楚点，那东西像是毒虫吗？\n"}
    else
      :ok
    end
  end

  # LPC: if( my_skill < 100 )
  #              return notify_fail("你的千蛛万毒手火候太浅，不能用来吸取毒素！\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "qianzhu-wandushou") < 100 do
      {:error, "你的千蛛万毒手火候太浅，不能用来吸取毒素！\n"}
    else
      :ok
    end
  end

  # LPC: if( objectp(me->query_temp("weapon")) )
  #              return notify_fail("你必须空手才能修炼千蛛万毒手！\n");
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手才能修炼千蛛万毒手！\n"}
    else
      :ok
    end
  end

  # LPC: if( me->is_fighting() )
  #              return notify_fail("战斗中无法修炼千蛛万毒手！\n");
  #      if( me->is_busy() )
  #              return notify_fail("你正忙着呢！\n");
  defp check_self_state(character) do
    combat = character.meta.combat

    cond do
      Combat.fighting?(combat) -> {:error, "战斗中无法修炼千蛛万毒手！\n"}
      Combat.busy?(combat) -> {:error, "你正忙着呢！\n"}
      true -> :ok
    end
  end

  # LPC: if( target->is_fighting() || target->is_busy() )
  #              return notify_fail("毒虫正忙着呢，不能和你配合！\n");
  defp check_worm_state(target) do
    if worm_busy?(target) do
      {:error, "毒虫正忙着呢，不能和你配合！\n"}
    else
      :ok
    end
  end

  defp worm_busy?(target) do
    combat = Map.get(target.meta, :combat, %{})

    Map.get(combat, :enemies, []) != [] or Map.get(combat, :busy, 0) > 0
  end

  # LPC: if( me->query_temp("wudu_suck") )
  #              return notify_fail("你正在修炼中！\n");
  defp check_wudu_suck(character) do
    if Combat.buff_active?(character.meta.combat, @wudu_suck_key) do
      {:error, "你正在修炼中！\n"}
    else
      :ok
    end
  end

  # LPC: if (! me->can_improve_skill("qianzhu-wandushou"))
  #              return notify_fail("你的实战经验不够，无法继续修炼千蛛万毒手！\n");
  defp check_can_improve(character) do
    if LearnGate.can_improve?(character.meta.stats, "qianzhu-wandushou") do
      :ok
    else
      {:error, "你的实战经验不够，无法继续修炼千蛛万毒手！\n"}
    end
  end

  # LPC: tg_age = (int)target->query("age");
  #       if( tg_age - my_skill >= 50 )
  #              return notify_fail(target->query("name") + "的毒力对你来说太强了，小心把小命送了！\n");
  #       if( my_skill - tg_age >= 50 )
  #              return notify_fail(target->query("name") + "的毒力对你来说已经太轻微了！\n");
  defp check_toxicity(character, target) do
    my_skill = Stats.skill(character.meta.stats, "qianzhu-wandushou")
    # 毒虫岁数未建模（stats 无 age 字段），默认 0
    tg_age = Map.get(target.meta, :age, 0)

    cond do
      tg_age - my_skill >= 50 ->
        {:error, worm_name(target) <> "的毒力对你来说太强了，小心把小命送了！\n"}

      my_skill - tg_age >= 50 ->
        {:error, worm_name(target) <> "的毒力对你来说已经太轻微了！\n"}

      true ->
        :ok
    end
  end

  # LPC: if( (int)me->query("neili") < 200 )
  #              return notify_fail("你的内力不够，不足以对抗毒气，别把小命送掉。\n");
  defp check_self_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的内力不够，不足以对抗毒气，别把小命送掉。\n"}
    else
      :ok
    end
  end

  # LPC: if( (int)target->query("qi") < 50 )
  #              return notify_fail( target->query("name") + "已经奄奄一息了，你"
  #                                  "无法从他体内吸取任何毒素！\n");
  defp check_worm_qi(target) do
    vitals = Map.get(target.meta, :vitals, %{})

    if Map.get(vitals, :qi, 0) < 50 do
      {:error, worm_name(target) <> "已经奄奄一息了，你无法从他体内吸取任何毒素！\n"}
    else
      :ok
    end
  end

  defp worm_name(target) do
    Map.get(target, :name, "")
  end

  # LPC: if( (int)me->query("qi") < 200 )
  #              return notify_fail( "你快不行了，再练会送命的！\n");
  defp check_self_qi(character) do
    if character.meta.vitals.qi < 200 do
      {:error, "你快不行了，再练会送命的！\n"}
    else
      :ok
    end
  end

  # LPC: tell_object(me, RED "你小心翼翼的将手伸到" + target->query("name") +
  #                       RED "的面前，它张嘴就咬住了你的中指。你深吸一口\n气，"
  #                       "面上顿时罩着一股黑气，豆大的汗珠从额头滚了下来。你只"
  #                       "觉得" + target->query("name") + RED "的\n毒素自伤处"
  #                       "源源不绝地流了进来，随真气遍布全身。\n\n" NOR );
  #      … improve_skill ×2 …
  #      tell_object(me, HIC "你的「千蛛万毒手」和「基本毒技」熟练度提高了！\n" NOR);
  #      me->set_temp("wudu_suck", 1);
  #      call_out("del_wudusuck", 3, me, target);
  defp apply_effect(conn, character, target) do
    narrative =
      "你小心翼翼的将手伸到" <> worm_name(target) <>
        "的面前，它张嘴就咬住了你的中指。你深吸一口气，面上顿时罩着一股黑气，豆大的汗珠从额头滚了下来。你只觉得" <> worm_name(target) <>
        "的\n毒素自伤处源源不绝地流了进来，随真气遍布全身。\n\n"

    conn =
      conn
      |> render(CommandView, "text", %{text: narrative})
      |> render(CommandView, "text", %{text: "你的「千蛛万毒手」和「基本毒技」熟练度提高了！\n"})

    # LPC: me->set_temp("wudu_suck", 1); call_out("del_wudusuck", 3, me, target);
    combat =
      character.meta.combat
      |> Combat.add_buff(%Combat.Buff{key: @wudu_suck_key, applies: %{}, duration: 3})

    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC del_wudusuck(): tell_object(me, RED "\n只见它的肚子越涨越大，“吧嗒”一声，松"
    #                          "开口掉在了地上。" + target->query("name") + RED
    #                          "吸饱了鲜\n血，身上透出一层宝光，身子顿时涨大"
    #                          "了许多！\n\n\n" NOR,);
    expire_message =
      "\n只见它的肚子越涨越大，“吧嗒”一声，松开口掉在了地上。" <> worm_name(target) <>
        "吸饱了鲜\n血，身上透出一层宝光，身子顿时涨大了许多！\n\n\n"

    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{
          key: @wudu_suck_key,
          applies: %{},
          message: expire_message
        }
      },
      3 * 1000
    )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
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
