defmodule Kantele.Combat.Skills.Performs.LiumaiShenjian.Zong do
  @moduledoc """
  perform「万剑纵横」（source liumai-shenjian/zong.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 准备 finger 为六脉神剑 →
  六脉神剑>=260 → 内功>=480 → 最大内力>=8500 → 真气>=1000 → 空手 → 目标存活。
  起手广播为单段合并文案；随后连出六招「少商/商阳/中冲/关冲/少泽/少冲」剑气，
  每招各自命中判定 `ap*3/4 + random(ap) > dp`（ap = 六脉神剑+经络学，
  dp 依次为 目标 parry/parry/dodge/dodge/force/force + 经络学），命中伤害
  `finger/2 + 六脉神剑`（30/30/40/40/60/60% 外伤比例）。攻击方无条件扣 800 真气、
  忙乱 3+random(4)。

  差异（TODO(migrate)）：
  - `.c` 里被注释掉的第一版判定（`/* ... */`）不参与文案比对，其文案只保留在
    文末 LPC 源码块里；
  - `do_damage(UNARMED_ATTACK, damage, percent, msg)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, div(damage*percent, 100))`；
  - 六招的命中/失手文案在 `.c` 里各自逐字出现（重复文案也按出现次数分别写出）；
  - ZONG 宏展开+去色后合并为单段「万剑纵横」，E 侧用 @move_name 属性插值复现；
  - `living(target)` 门槛由目标侧 combat/perform-incoming 的死亡检查兜底。
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

  @perform_id "liumai-shenjian/zong"
  @move_name "「万剑纵横」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "liumai-shenjian")

    # LPC: damage = finger / 2 + liumai-shenjian;
    #      ap = liumai-shenjian + jingluo-xue;
    damage = div(Stats.skill(stats, "finger"), 2) + Stats.skill(stats, "liumai-shenjian")
    ap = Stats.skill(stats, "liumai-shenjian") + Stats.skill(stats, "jingluo-xue")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_prepared(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(combat),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/liumai-shenjian/zong"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "liumai-shenjian")
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared = Stats.prepared_perform(stats, "finger")

    if prepared == nil or hd(String.split(prepared, "/")) != "liumai-shenjian" do
      {:error, "你没有准备使用六脉神剑，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: liumai-shenjian < 260 / force < 480
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "liumai-shenjian") < 260 ->
        {:error, "你的六脉神剑修为有限，无法使用#{@move_name}！\n"}

      Stats.skill(stats, "force") < 480 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: max_neili < 8500 / neili < 1000
  # （注意 `.c` 的 "不够,无法施展" 用的是半角逗号，逐字保留）
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 8500 ->
        {:error, "你的内力修为不够,无法施展#{@move_name}！\n"}

      vitals.neili < 1000 ->
        {:error, "你的真气不够，现在无法施展#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你必须是空手才能施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIM "$N" HIM "一声清啸，十指纷弹，顿觉六脉剑谱已涌上心头，此起"
    #               "彼伏、连绵不绝。霎时剑气如奔，连绵无尽的万道剑气豁然贯向$n"
    #               HIM "！\n" NOR;（相邻字面量合并为单段）
    # LPC: me->add("neili", -800); me->start_busy(3 + random(4));（均无条件）
    rng = &:rand.uniform/1

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 800}
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn =
      Broadcast.publish(
        conn,
        "$N一声清啸，十指纷弹，顿觉六脉剑谱已涌上心头，此起彼伏、连绵不绝。霎时剑气如奔，连绵无尽的万道剑气豁然贯向$n！\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage = Map.get(data, :damage, 0)

    # LPC: 六招依次为 少商/商阳/中冲/关冲/少泽/少冲 剑气；
    #      dp 依次为 parry/parry/dodge/dodge/force/force + jingluo-xue；
    #      外伤比例 30/30/40/40/60/60。命中/失手文案逐字按 `.c` 各写一遍。
    moves = [
      %{
        dp: "parry",
        percent: 30,
        # LPC: HIM "$N" HIM "双手拇指同时捺出，嗤嗤两声急响，「" + HIY "少商剑"
        #      + HIM "」有如石破天惊、风雨大至。\n"
        # （中间被 `+` 隔成三段，无变量，用 list + Enum.join 保持拆分）
        lead: Enum.join(
                ["$N双手拇指同时捺出，嗤嗤两声急响，「", "少商剑", "」有如石破天惊、风雨大至。\n"],
                ""
              ),
        hit: "$n奋力抵挡，却哪里招架得住，被$N这一指戳得鲜血迸流！\n",
        miss: "$n使出浑身解数，终于将$N这一指架开，丝毫无损。\n"
      },
      %{
        dp: "parry",
        percent: 30,
        lead: "接着$N拇指一屈，食指随即点出，嗤嗤两声急响，「商阳剑」激射刺出。\n",
        hit: "$n试图抵挡，只听哧的一声，无形剑气已破体而入，透体而出！\n",
        miss: "$n使出浑身解数，终于将$N这一指架开，丝毫无损。\n"
      },
      %{
        dp: "dodge",
        percent: 40,
        lead: "只见$N右手中指一竖，「中冲剑」向前刺出。真气鼓荡，嗤然声响，无形剑气直指$n。 \n",
        hit: "$n一愣，只听哧啦的一声，已被剑气划得鲜血飞溅！\n",
        miss: "$n使出浑身解数，终于将$N这一指架开，丝毫无损。\n"
      },
      %{
        dp: "dodge",
        percent: 40,
        lead: "$N无名指轻轻一挥，「嗤啦」一声，拙滞古朴的「关冲剑」剑气向$n直射而出。\n",
        hit: "$n躲闪不及，被戳了碗口大个血窟窿，鲜血喷涌而出！\n",
        miss: "$n左闪右跳，终于将$N这一指避开，丝毫无损。\n"
      },
      %{
        dp: "force",
        percent: 60,
        lead: "忽见$N左手小指一伸，一条气流从少冲穴中激射而出，一股「少泽剑」登时射向$n。\n",
        hit: "$n运气抵挡，只觉得一股透体凉意袭了上来，一个激凌，丹田立刻变得空空荡荡！\n",
        miss: "$n运气抵挡，硬生生接下了$N这一指。\n"
      },
      %{
        dp: "force",
        percent: 60,
        lead: "最后$N右手小指一挥，一招「少冲剑」点点刺刺破空刺出，宛如雕花刺画一般。\n",
        hit: "$n已然放弃抵抗，任凭气流摧袭只盼望一切早点结束....\n",
        miss: "$n运气抵挡，终于接下了$N这一指，已是狼狈不堪。\n"
      }
    ]

    {conn, character} =
      Enum.reduce(moves, {conn, character}, fn move, {conn, character} ->
        resolve_move(conn, character, attacker, rng, ap, damage, move)
      end)

    conn
    |> put_character(character)
  end

  # 六招共用同一 damage（finger/2 + 六脉神剑），各自命中判定与外伤比例。
  defp resolve_move(conn, character, attacker, rng, ap, damage, move) do
    stats = character.meta.stats
    dp = Stats.skill(stats, move.dp) + Stats.skill(stats, "jingluo-xue")

    # LPC: if (ap * 3 / 4 + random(ap) > dp)
    hit? = div(ap * 3, 4) + Engine.rand(rng, ap) > dp

    conn =
      Broadcast.publish(conn, move.lead, n1: attacker.name, n2: character.name)

    {conn, character} =
      if hit? do
        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * move.percent, 100))

        {conn, %{character | meta: %{character.meta | vitals: vitals}}}
      else
        {conn, character}
      end

    msg = if hit?, do: move.hit, else: move.miss

    conn =
      Broadcast.publish(conn, msg, n1: attacker.name, n2: character.name)

    {conn, character}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZONG "「" HIM "万剑纵横" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int damage, skill;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/zong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
  #                 return notify_fail("你没有准备使用六脉神剑，无法施展" ZONG "。\n");
  # 
  #         skill = me->query_skill("liumai-shenjian", 1);
  # 
  #         if (skill < 260)
  #                 return notify_fail("你的六脉神剑修为有限，无法使用" ZONG "！\n");
  # 
  #         if (me->query_skill("force") < 480)
  #                 return notify_fail("你的内功火候不够，难以施展" ZONG "！\n");
  # 
  #         if (me->query("max_neili") < 8500)
  #                 return notify_fail("你的内力修为不够,无法施展" ZONG "！\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你的真气不够，现在无法施展" ZONG "！\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("你必须是空手才能施展" ZONG "！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  # 
  #         msg = HIM "$N" HIM "一声清啸，十指纷弹，顿觉六脉剑谱已涌上心头，此起"
  #               "彼伏、连绵不绝。霎时剑气如奔，连绵无尽的万道剑气豁然贯向$n" HIM
  #               "！\n" NOR;
  # /*
  #         ap = me->query_skill("finger") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  #         me->start_busy(3);
  # 
  #         if ((int)target->query_skill("jingluo-xue", 1) >= 300
  #             && target->query_skill("dodge", 1) >= 300
  #             && random (10) == 1 )
  #         {
  #                 me->add("neili", -600);
  #                 me->start_busy(4);
  #                 msg += HIY "但见$n" HIY "会心一笑，轻拂衣袖，轻易的躲过这一招！\n"NOR;
  #         } else
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 damage = ap * 3 / 2 + random(ap);
  #                 me->add("neili", -800);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 200,
  #                                            HIR "只听$n" HIR "一声惨叫，万道剑气已"
  #                                            "透体而过，伤口处鲜血顿时狂涌，痛苦难当！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -400);
  #                 me->start_busy(4);
  #                 msg += CYN "$n" CYN "见$N" CYN "来势汹涌，不敢轻易"
  #                        "招架，急忙提气跃开。\n" NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # */
  # 
  # 
  #   damage = (int)me->query_skill("finger",1)/2 + (int)me->query_skill("liumai-shenjian",1);
  # 
  # 
  #        // 第一招
  #         ap = me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("parry",1) + target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIM "$N" HIM "双手拇指同时捺出，嗤嗤两声急响，「"+ HIY "少商剑"+ HIM "」有如石破天惊、风雨大至。\n" NOR ;
  # 
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "奋力抵挡，却哪里招架得住，被$N"
  #                                            HIR "这一指戳得鲜血迸流！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "使出浑身解数，终于将$N"
  #                        CYN "这一指架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         // 第二招
  #         ap = me->query_skill("liumai-shenjian",1) + me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("parry",1)+ target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIY "接着" HIY "$N" HIY "拇指一屈，食指随即点出，嗤嗤两声急响，「" HIR "商阳剑" HIY "」激射刺出。\n"NOR;
  # 
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "试图抵挡，只听哧的一声，"
  #                                            HIR "无形剑气已破体而入，透体而出！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "使出浑身解数，终于将$N"
  #                        CYN "这一指架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         //// 第三招
  #         ap = me->query_skill("liumai-shenjian",1)+me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("dodge",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIG "只见" HIG "$N" HIG "右手中指一竖，「" HIC "中冲剑" HIG "」向前刺出。真气鼓荡，嗤然声响，无形剑气直指$n。 \n"NOR;
  # 
  #         if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "一愣，只听哧啦的一声，"
  #                                            HIR "已被剑气划得鲜血飞溅！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "使出浑身解数，终于将$N"
  #                        CYN "这一指架开，丝毫无损。\n" NOR;
  #         }
  # 
  #         //// 第四招
  #         ap = me->query_skill("liumai-shenjian",1)+me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("dodge",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIC "$N" HIC "无名指轻轻一挥，「嗤啦」一声，拙滞古朴的「" MAG "关冲剑" HIC "」剑气向" HIC"$n" HIC"直射而出。\n"NOR;
  # 
  #          if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "躲闪不及，被戳了碗口大个血窟窿，"
  #                                            HIR "鲜血喷涌而出！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "左闪右跳，终于将$N"
  #                        CYN "这一指避开，丝毫无损。\n" NOR;
  #         }
  # 
  # 
  #         //// 第五招
  #         ap = me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("force",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIB "忽见$N" HIB "左手小指一伸，一条气流从少冲穴中激射而出，一股「" HIW "少泽剑" HIB "」登时射向$n。\n"NOR;
  # 
  #          if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "$n" HIR "运气抵挡，只觉得一股透体凉意"
  #                                            "袭了上来，一个激凌，丹田立刻变得空空荡荡！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "运气抵挡，硬生生接下了$N"
  #                        CYN "这一指。\n" NOR;
  #         }
  #         //// 第六招
  #         ap = me->query_skill("liumai-shenjian",1)+ me->query_skill("jingluo-xue", 1);
  #         dp = target->query_skill("force",1)+target->query_skill("jingluo-xue", 1);
  # 
  #         msg += HIW "最后"HIW "$N" HIW"右手小指一挥，一招「" HIG "少冲剑" HIW "」点点刺刺破空刺出，宛如雕花刺画一般。\n"NOR;
  # 
  #          if (ap * 3 / 4 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "$n" HIR "已然放弃抵抗，任凭气流摧袭"
  #                                            "只盼望一切早点结束....\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "运气抵挡，终于接下了$N"
  #                        CYN "这一指，已是狼狈不堪。\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -800);
  #         me->start_busy(3 + random(4));
  # 
  #         return 1;
  # }
end
