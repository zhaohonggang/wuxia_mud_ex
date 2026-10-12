defmodule Kantele.Combat.Skills.Performs.RulaiZhang.Zong do
  @moduledoc """
  perform「万佛朝宗」（source rulai-zhang/zong.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "rulai-zhang/zong"
  @move_name "「万佛朝宗」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "rulai-zhang")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: Stats.skill(stats, "strike"),
          max_neili: character.meta.vitals.max_neili,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 280 -> {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "rulai-zhang") < 150 -> {:error, "你千手如来掌火候不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "hunyuan-yiqi" ->
        {:error, "你现在没有激发心意气内功为内功，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "strike") == nil or
          String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "rulai-zhang" ->
        {:error, "你没有准备千手如来掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
      vitals.neili < 500 -> {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # 前置广播（neili 消耗 / start_busy / do_attack 次数依赖命中与内力分支，交由 do_resolve）
    Broadcast.publish(
      conn,
      "$N当下更不耽搁，高呼佛号，轻飘飘拍出一掌，招式甚为寻常。但掌到中途，忽然微微摇晃，登时一掌变两掌，两掌变四掌，四掌变八掌！铺天盖地拍向$n。",
      n1: character.name,
      n2: target.name
    )
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「万佛朝宗」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    max_neili = Map.get(data, :max_neili, 0)
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry") + Stats.query_dex(stats) * 10
    enemy_max = character.meta.vitals.max_neili

    hit = div(ap, 2) + rng.(ap) > dp

    # LPC: 命中且 me->max_neili > target->max_neili * 2 时进入"万佛朝宗"断念斩杀分支
    special = hit and max_neili > enemy_max * 2

    {character, feedback} =
      cond do
        special ->
          # set("eff_qi", 0); set("eff_jing", 0); neili -500; start_busy(3); 9× do_attack
          vitals = %{character.meta.vitals | qi: 0, jing: 0}

          {apply_hits(
             %{character | meta: %{character.meta | vitals: vitals}},
             ap,
             dp,
             9,
             ap,
             rng
           ), {500, 3}}

        hit ->
          # count = ap / 9; neili -300; start_busy(1 + random(6)); 6× do_attack
          {apply_hits(character, ap, dp, 6, div(ap, 9), rng), {300, 1 + rng.(6)}}

        true ->
          # count = 0; neili -300; start_busy(1 + random(6)); 6× do_attack
          {apply_hits(character, ap, dp, 6, 0, rng), {300, 1 + rng.(6)}}
      end

    {cost, busy} = feedback
    Performs.feedback(attacker, cost, busy)

    msg =
      cond do
        special ->
          "随即又听$N高声喝道：「我佛如来」顷刻间，但见$N八掌又变为十六掌，进而再幻化为三十二掌，掌势层层叠叠，波澜壮阔，气势磅礴，荡气回肠。如海潮般向$n涌去。\n\n$n面对这无穷无尽的掌势，竟然放弃了抵抗，面如死灰坐以待毙。"

        hit ->
          "\n$n见掌势层层叠叠，有如海潮，一时只觉头晕目眩，难作抵挡。"

        true ->
          "\n$n见掌势层层叠叠，有如海潮，连忙振作精神，勉强抵挡。"
      end

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # 折算 n 次 do_attack：逐次命中累计伤害（apply/attack 加成 bonus 并入判定）
  defp apply_hits(character, ap, dp, n, bonus, rng) do
    damage =
      Enum.reduce(1..n, 0, fn _, damage_acc ->
        if ap + bonus + rng.(ap) > dp do
          per_hit = max(div(ap, 12), 1)
          damage_acc + per_hit + rng.(per_hit)
        else
          damage_acc
        end
      end)

    if damage > 0 do
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      %{character | meta: %{character.meta | vitals: vitals}}
    else
      character
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3);", "//  if (random(5) < 2 && ! target->is_busy())", "//   target->start_busy(1);", "//  if (random(5) < 2 && ! target->is_busy())", "//          target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"force", "280"}, {"rulai-zhang", "150"}], "map_gates": [{"force", "hunyuan-yiqi"}], "prepared_gates": [{"strike", "rulai-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "set_flags": [{"eff_jing", "0"}, {"eff_qi", "0"}], "var_gates": [{"i", "6"}, {"i", "9"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZONG "「" HIY "万佛朝宗" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/rulai-zhang/zong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZONG "只能对战斗中的对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZONG "只能空手施展。\n");
  #                 
  #         if (me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不够，难以施展" ZONG "。\n");
  # 
  #         if ((int)me->query_skill("force") < 280)
  #                 return notify_fail("你的内功火候不足，难以施展" ZONG "。\n");
  # 
  #         if ((int)me->query_skill("rulai-zhang", 1) < 150)
  #                 return notify_fail("你千手如来掌火候不够，难以施展" ZONG "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "hunyuan-yiqi") 
  #                 return notify_fail("你现在没有激发心意气内功为内功，难以施展" ZONG "。\n");
  #         if (me->query_skill_prepared("strike") != "rulai-zhang")
  #                 return notify_fail("你没有准备千手如来掌，难以施展" ZONG "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" ZONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "\n$N" HIY "当下更不耽搁，高呼佛号，轻飘飘拍出一掌，招式"
  #               "甚为寻常。但掌到中途，忽然微微摇晃，登时一掌变两掌，两掌变四"
  #               "掌，四掌变八掌！铺天盖地拍向$n" HIY "。" NOR;
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 // 增加点感官刺激:)
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         me->start_busy(3);
  #                         me->add("neili", -500);
  #                         msg += HIY "随即又听$N" HIY "高声喝道：「" HIR "我佛如来" HIY
  #                                "」顷刻间，但见$N" HIY "八掌又变为十六掌，进而再幻化为"
  #                                "三十二掌，掌势层层叠叠，波澜壮阔，气势磅礴，荡气回肠"
  #                                "。如海潮般向$n" HIY "涌去。\n\n" HIR "$n" HIR "面对这"
  #                                "无穷无尽的掌势，竟然放弃了抵抗，面如死灰坐以待毙。\n" NOR;
  # 
  #                         message_sort(msg, me, target);
  #                         target->set("eff_qi", 0);
  #                         target->set("eff_jing", 0);
  #                      //   target->unconcious(me);
  #                         me->add_temp("apply/attack", ap);
  #                         me->add_temp("rulai-zhang/hit_msg", 1);
  #                         for (i = 0; i < 9; i++)
  #                         {
  #                                 if (! me->is_fighting(target))
  #                                 break;
  #                               //  if (random(5) < 2 && ! target->is_busy())
  #                              //   target->start_busy(1);
  # 
  #                                 COMBAT_D->do_attack(me, target, 0, 0);
  #                         }
  #                         me->add_temp("apply/attack", -ap);
  #                         me->delete_temp("rulai-zhang/hit_msg");
  #                         return 1;
  #                 } else
  #                 {
  #                         count = ap / 9;
  # 
  #                         msg += HIR "\n$n" HIR "见掌势层层叠叠，有如海潮，一时"
  #                                "只觉头晕目眩，难作抵挡。\n" NOR;
  #                 }
  #         } else
  #         {
  #                 msg += HIC "\n$n" HIC "见掌势层层叠叠，有如海潮，连忙"
  #                        "振作精神，勉强抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_sort(msg, me, target);
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("rulai-zhang/hit_msg", 1);
  #         me->add("neili", -300);
  # 
  #         for (i = 0; i < 6; i++)
  # 
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #               //  if (random(5) < 2 && ! target->is_busy())
  #               //          target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(6));
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->delete_temp("rulai-zhang/hit_msg");
  #         return 1;
  # }
end
