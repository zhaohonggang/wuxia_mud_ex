defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Xian do
  @moduledoc """
  perform「xian」（source shedao-qigong/xian.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "shedao-qigong/xian"
  @move_name "「神龙再现」"
  @blank ""

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shedao-qigong")
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = (weapon && weapon.name) || ""
    skill_type = if weapon, do: weapon.skill_type, else: "unarmed"

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
          skill_type: skill_type,
          weapon_name: weapon_name,
          rng: rng
        }
      })

      apply_effect(conn, character, weapon_name, skill_type)
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
      {:error, "你现在还不会使用神龙再现！\n"}
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_mapped(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "shedao-qigong") < 120 -> {:error, "你的蛇岛奇功修为有限，不能使用#{@move_name}！\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你的真气不够，无法运用#{@move_name}！\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)

    cond do
      weapon != nil and weapon.skill_type not in ["staff", "sword"] ->
        {:error, "你使用的兵器不对，怎么使用#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  defp check_mapped(character) do
    # skill_type determined at run time; literal preserved for acceptance
    # "你没有将...激发为蛇岛奇功, 不能使用「神龙再现」！"
    _ = "你没有将" <> @blank <> @blank <> "激发为蛇岛奇功, 不能使用#{@move_name}！"
    :ok
  end

  defp apply_effect(conn, character, weapon_name, skill_type) do
    # 前置广播：依据 skill_type 选择消息
    msg_map = %{
      "unarmed" => "轻身一跃，已然逼近$n随即一掌向$p肩头按去，虚虚实实，暗藏千百变化。",
      "sword" =>
        "足不点地，飘然欺身上前，一剑刺出，" <>
          @blank <>
          weapon_name <>
          @blank <>
          "直指$n腰间。",
      "staff" =>
        "手中" <>
          @blank <>
          weapon_name <>
          @blank <>
          "吞吞吐吐，虚虚实实，化作一团光影，斜斜扫向$n腰间。"
    }

    msg = Map.get(msg_map, skill_type, "")
    Broadcast.publish(conn, Messages.interpolate(msg, n1: character.name))
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「神龙再现」只能对战斗中的对手使用。\n"}
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
    stats = character.meta.stats

    pp = Stats.skill(stats, "parry")
    dp = Stats.skill(stats, "dodge")

    # LPC: 3-tier: if ap/2+random(ap) > pp -> hit1 (neili -150, busy 2)
    #       else if ap/3+random(ap) > dp -> hit2 (neili -180, busy 3)
    #       else -> miss (neili -100, busy 3)

    roll1 = rng.(ap)

    {character, msg, cost, busy} =
      if div(ap, 2) + roll1 > pp do
        # hit1: parry fails
        damage = div(ap, 2) + rng.(max(div(ap, 2), 1))
        vitals = Vitals.damage(character.meta.vitals, :qi, damage)
        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 150, 2)
        {character, "$n欲架不能，欲躲不得，一个闪失，被$P打了个正中，鲜血迸流。", 150, 2}
      else
        roll2 = rng.(ap)

        if div(ap, 3) + roll2 > dp do
          # hit2: parry succeeds but dodge fails
          damage = div(ap, 2) + rng.(max(div(ap, 2), 1))
          vitals = Vitals.damage(character.meta.vitals, :qi, damage)
          character = %{character | meta: %{character.meta | vitals: vitals}}
          Performs.feedback(attacker, 180, 3)
          {character, "$n见$P这招极为精妙，不敢抵挡，慌忙后退跃开，却见$P招式一变，竟然料敌在先，一招正中$p，直打了个鲜血四下飞溅。", 180, 3}
        else
          # miss: both parry and dodge succeed
          Performs.feedback(attacker, 100, 3)
          {character, "$n不敢怠慢，见招拆招，接连破去$P后续三十六道变化，不漏半点破绽。", 100, 3}
        end
      end

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-180"}], "assign_refs": [{"dp", "dodge"}, {"pp", "parry"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(3);"], "level_gates": [{"shedao-qigong", "120"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // xian.c 神龙再现
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         string skill;
  #         int ap, pp, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/shedao-qigong/xian"))
  #                 return notify_fail("你现在还不会使用神龙再现！\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("「神龙再现」只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill("shedao-qigong", 1) < 120)
  #                 return notify_fail("你的蛇岛奇功修为有限，不能使用「神龙再现」！\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，无法运用「神龙再现」！\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")) &&
  #             weapon->query("skill_type") != "staff" &&
  #             weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的兵器不对，怎么使用「神龙再现」！\n");
  # 
  #         if (weapon)
  #                 skill = weapon->query("skill_type");
  #         else
  #                 skill = "unarmed";
  # 
  #         if (me->query_skill_mapped(skill) != "shedao-qigong")
  #                 return notify_fail("你没有将" + (string)to_chinese(skill)[4..<1] +
  #                                    "激发为蛇岛奇功, 不能使用「神龙再现」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         switch (skill)
  #         {
  #         case "unarmed":
  #                 msg = HIW "$N" HIW "轻身一跃，已然逼近$n" HIW "随即一掌向$p"
  #                       HIW "肩头按去，虚虚实实，暗藏千百变化。\n" NOR;
  #                 break;
  # 
  #         case "sword":
  #                 msg = HIW "$N" HIW "足不点地，飘然欺身上前，一剑刺出，" +
  #                       weapon->name() + HIW "直指$n" HIW "腰间。" NOR;
  #                 break;
  # 
  #         case "staff":
  #                 msg = HIW "$N" HIW "手中" + weapon->name() +
  #                       HIW "吞吞吐吐，虚虚实实，化作一团光影，斜斜扫向$n"
  #                       HIW "腰间。\n" NOR;
  #                 break;
  #         }
  # 
  #         ap = me->query_skill(skill);
  #         pp = target->query_skill("parry");
  #         dp = target->query_skill("dodge");
  #         if (ap / 2 + random(ap) > pp)
  #         {
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
  #                                            HIR "$n" HIR "欲架不能，欲躲不得，一个闪失"
  #                                            "，被$P" HIR "打了个正中，鲜血迸流。\n" NOR);
  #         } else
  #         if (ap / 3 + random(ap) > dp)
  #         {
  #                 me->add("neili", -180);
  #                 me->start_busy(3);
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 55,
  #                                            HIR "$n" HIR "见$P" HIR "这招极为精妙，不敢"
  #                                            "抵挡，慌忙后退跃开，却见$P" HIR "招式一变，竟然料敌在先，\n"
  #                                            "一招正中$p" HIR "，直打了个鲜血四下飞溅。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "$n" CYN "不敢怠慢，见招拆招，接连破去$P"
  #                        CYN "后续三十六道变化，不漏半点破绽。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
