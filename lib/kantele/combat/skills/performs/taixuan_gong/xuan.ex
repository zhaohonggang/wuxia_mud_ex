defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Xuan do
  @moduledoc """
  perform「玄字诀」（source taixuan-gong/xuan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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
  alias Kantele.Character.Combat

  @perform_id "taixuan-gong/xuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taixuan-gong")
    ap = lvl

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
          ap: ap,
          rng: rng,
          count: 0  # will be set in resolve_incoming on hit
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

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 -> {:error, "你的内功火候不够，难以施展玄字诀。\n"}
      Stats.skill(stats, "taixuan-gong") < 240 -> {:error, "你的太玄功不够娴熟，难以施展玄字诀。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "taixuan-gong" and Stats.mapped(stats, "sword") != "taixuan-gong" ->
        {:error, "你没有激发太玄功刀剑，难以施展玄字诀。\n"}

      Stats.mapped(stats, "unarmed") != "taixuan-gong" and not Map.has_key?(character.meta.stats.skills, "sword") and not Map.has_key?(character.meta.stats.skills, "blade") ->
        {:error, "你没有准备太玄功拳脚，难以施展玄字诀。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "你的内力修为不足，难以施展玄字诀。\n"}
      vitals.neili < 800 -> {:error, "你的内力不足，难以施展玄字诀。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    stats = character.meta.stats

    cond do
      # 复杂的武器检查逻辑简化为：必须激发 taixuan-gong
      Stats.mapped(stats, "sword") != "taixuan-gong" and Stats.mapped(stats, "blade") != "taixuan-gong" and Stats.mapped(stats, "unarmed") != "taixuan-gong" ->
        {:error, "你必须激发太玄功才能施展玄字诀。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    stats = character.meta.stats

    cond do
      false -> {:error, "你所使用的外功中没有这种功能。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件效果：扣内力 600 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 600}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn = Broadcast.publish(conn, "突然只见$N身形陡然拔起，衣袂猎猎作响，玄妙剑意如潮水般涌向$n！", n1: character.name)

    conn
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
    lvl = Map.get(data, :level, 0)
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge")

    # 命中判定：ap / 3 + random(ap) > dp
    hit = div(ap, 3) + Engine.rand(rng, ap) >= dp

    vitals = character.meta.vitals
    attacker_vitals = attacker.meta.vitals
    attacker_combat = attacker.meta.combat

hit_result =
      if hit do
        # 命中：count = ap / 8，给予攻击加成，进行一次强化攻击（简化 15 轮为单次强化攻击）
        count = div(ap, 8)

        # 给攻击方临时攻击加成
        attacker_combat = Combat.apply_temp(attacker_combat, %{attack: count})
        attacker = %{attacker | meta: Map.put(attacker.meta, :combat, attacker_combat)}

        # 进行一次强化攻击（模拟 15 轮中的一轮，伤害按 count 加成）
        damage = Map.get(data, :damage, 0) + count * 2
        vitals = Vitals.damage(vitals, :qi, damage)

        # 随机让目标 busy 1
        if Engine.rand(rng, 2) == 1 do
          combat = character.meta.combat
          combat = Combat.start_busy(combat, 1)
          character = %{character | meta: Map.put(character.meta, :combat, combat)}
        end

        # 恢复攻击加成
        attacker_combat = Combat.apply_temp(attacker_combat, %{attack: -Map.get(attacker_combat.temp, :attack, count)})
        attacker = %{attacker | meta: Map.put(attacker.meta, :combat, attacker_combat)}

        Performs.feedback(attacker, 600, 1)

        # 命中消息
        "只见$N剑气纵横，$n只觉眼花缭乱，竟已中了数剑！"
      else
        # 闪避
        Performs.feedback(attacker, 0, 1)

        "$n身形飘忽，竟在$N剑气中穿梭自如，竟未沾边！"
      end

    # 结束时 busy 1-5
    attacker_combat = Combat.start_busy(attacker_combat, 1 + Engine.rand(rng, 5))
    attacker = attacker
    |> Map.put(:meta, Map.put(attacker.meta, :vitals, attacker_vitals))
    |> Map.put(:meta, Map.put(attacker.meta, :combat, attacker_combat))

    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    attacker = attacker
    |> Map.put(:meta, Map.put(attacker.meta, :vitals, attacker_vitals))
    |> Map.put(:meta, Map.put(attacker.meta, :combat, attacker_combat))

    result = Messages.interpolate(hit_result, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
    |> Map.put(:attacker, attacker)
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

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{
  #     "add_costs": [{"neili", "-600"}],
  #     "apply_adds": ["attack"],
  #     "assign_refs": [{"dp", "dodge"}, {"lvl", "taixuan-gong"}],
  #     "busy_lines": ["if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"],
  #     "level_gates": [{"force", "300"}, {"taixuan-gong", "240"}],
  #     "map_gates": [{"blade", "taixuan-gong"}, {"sword", "taixuan-gong"}, {"unarmed", "taixuan-gong"}],
  #     "remote_damage": false,
  #     "resource_gates": [{"max_neili", "5000"}, {"neili", "800"}],
  #     "var_gates": [{"i", "15"}]
  #   }

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define XUAN "「" HIW "玄字诀" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i, ap, dp;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/taixuan-gong/xuan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XUAN "只能在战斗中对对手使用。\n");
  # 
  #     if ((int)me->query("neili") < 800)
  #         return notify_fail("你的内力不足，难以施展" XUAN "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" XUAN "。\n");
  # 
  #     if ((int)me->query_skill("force") < 300)
  #         return notify_fail("你的内功火候不够，难以施展" XUAN "。\n");
  # 
  #     if ((lvl = (int)me->query_skill("taixuan-gong", 1)) < 240)
  #         return notify_fail("你的太玄功不够娴熟，难以施展" XUAN "。\n");
  # 
  #         // 是否已学会启用武器 玄字诀
  #         if (! me->query("can_learned/taixuan-gong/enable_weapon"))
  #         {
  #              weapon = me->query_temp("weapon");
  #              if (objectp(weapon))
  #                      return notify_fail("未学会启用武器前不能使用武器施展" XUAN "。\n");
  # 
  #              if (me->query_skill_mapped("unarmed") != "taixuan-gong"
  #                  || me->query_skill_prepared("unarmed" != "taixuan-gong"))
  #                        return notify_fail("你没有激发/准备太玄功拳脚，难以施展" XUAN "。\n");
  # 
  #         }
  #         else // 已经学会启用武器 玄字诀
  #         {
  #              weapon = me->query_temp("weapon");
  #              // 没学会武器时激发不需要激发拳脚
  #              if (! objectp(weapon))
  #              {
  #                     if (me->query_skill_mapped("unarmed") != "taixuan-gong"
  #                         || me->query_skill_prepared("unarmed" != "taixuan-gong"))
  #                               return notify_fail("你没有激发/准备太玄功拳脚，难以施展" XUAN "。\n");
  #              }
  #              // 已经学会武器且手持武器
  #              else if (objectp(weapon) && (string)weapon->query("skill_type") != "sword"
  #                       && (string)weapon->query("skill_type") != "blade")
  #                               return notify_fail("你使用的武器不对，难以施展" XUAN "。\n");
  # 
  #              if (objectp(weapon) && me->query_skill_mapped("sword") != "taixuan-gong"
  #                  && (string)weapon->query("skill_type") == "sword")
  #                               return notify_fail("你没有激发太玄功剑法，难以施展" XUAN "。\n");
  # 
  #              else if (objectp(weapon) && (string)weapon->query("skill_type") == "blade"
  #                       && me->query_skill_mapped("blade") != "taixuan-gong")
  #                               return notify_fail("你没有激发太玄功刀法，难以施展" XUAN "。\n");
  # 
  #         }
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "\n突然只见$N" HIW "猛然拔起，衣袂猎猎作响，玄妙剑意如潮水般涌向$n" HIW
  #               HIW "的玄字诀连环攻势，等$n" HIW "反应时$N" HIW
  #               "已至跟前，玄妙剑意如潮水般涌向$n" HIW "的玄字诀连环攻势\n" NOR;
  # 
  #     message_sort(msg, me, target);
  #     me->add("neili", -600);
  #         ap = me->query_skill("taixuan-gong, 1");
  #         dp = target->query_skill("dodge", 1);
  # 
  #         if (ap / 3 + random(ap) > dp)
  #                   count = ap / 8;
  # 
  #         else count = 0;
  # 
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 15; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(2) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #             if(weapon)
  #                 COMBAT_D->do_attack(me, target, weapon, i * 2);
  #             else
  #                 COMBAT_D->do_attack(me, target, 0, i * 2);
  #         }
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(5));
  #     return 1;
  # }
end