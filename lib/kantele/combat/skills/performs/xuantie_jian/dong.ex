defmodule Kantele.Combat.Skills.Performs.XuantieJian.Dong do
  @moduledoc """
  perform「大江东去」（source xuantie-jian/dong.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuantie-jian/dong"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuantie-jian")
    ap = Stats.skill(stats, "sword") + Stats.query_str(stats) * 5

    # LPC: if (me->query("character") == "光明磊落" || me->query("character")=="国土无双") ap += ap / 5;
    ap =
      if Map.get(character.meta, :character) in ["光明磊落", "国土无双"] do
        ap + div(ap, 5)
      else
        ap
      end

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
  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character) do
      :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)

    cond do
      weapon == nil or Map.get(weapon, :skill_type) != "sword" ->
        {:error, "你使用的武器不对，难以施展「大江东去」。\n"}

      Map.get(weapon, :weight, 0) < 25000 and not Map.get(weapon, :item_make, false) ->
        {:error, "你手中的" <> weapon_name(combat) <> "分量不够，难以施展「大江东去」。\n"}

      true ->
        :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 400 -> {:error, "你的内功火候不够，难以施展「大江东去」。\n"}
      Stats.skill(stats, "xuantie-jian") < 200 -> {:error, "你的玄铁剑法不够娴熟，难以施展「大江东去」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "xuantie-jian" -> {:error, "你没有激发玄铁剑法，难以施展「大江东去」。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 1000 -> {:error, "你现在的内力不足，难以施展「大江东去」。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：前置广播（消耗/Busy 由目标侧 feedback 处理）
    # LPC: msg = ... "接着单" "手一振，手中" + wp + "\n随即横空卷出..."（在 wp 处拆成两段）
    conn =
      Broadcast.publish(
        conn,
        "$N暗自凝神，顿时一股气劲由身后澎湃迸发，接着单手一振，手中" <>
          weapon_name(character.meta.combat) <>
          "随即横空卷出，激得周围尘沙腾起，所施正是玄铁剑法「大江东去」。",
        n1: character.name
      )

    conn
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「大江东去」只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name) || ""
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
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    damage = ap + Engine.rand(rng, max(ap, 1))
    dp = Stats.skill(stats, "force") + Stats.query_str(stats) * 5
    hit? = div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp

    # LPC: 反震/碎兵分支： "手中" + weapon_t->name() + "再也拿持不住..." / "碎掉的" + name
    weapon_t = Combat.weapon(character.meta.combat)
    weapon_t_name = weapon_t && Map.get(weapon_t, :name)

    conn =
      if weapon_t_name do
        conn
        |> Broadcast.publish(
          "$n只觉得一股大力传来，手中" <> weapon_t_name <> "再也拿持不住，脱手而出！\n",
          n1: attacker.name,
          n2: character.name
        )
        |> Broadcast.publish(weapon_t_name <> "已经碎掉了，没法装备了。\n",
          n1: attacker.name,
          n2: character.name
        )
        |> Broadcast.publish("碎掉的" <> weapon_t_name, n1: attacker.name, n2: character.name)
      else
        conn
      end

    vitals =
      if hit? do
        Vitals.damage(character.meta.vitals, :qi, damage)
      else
        character.meta.vitals
      end

    combat =
      if hit? do
        Combat.start_busy(character.meta.combat, 1)
      else
        character.meta.combat
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    Performs.feedback(attacker, if(hit?, do: 400, else: 200), 2)

    msg =
      if hit? do
        "结果$n奋力招架，却被$N这一剑震的飞起，口中鲜血狂吐不止！"
      else
        "可是$n看破了$N的企图，急忙斜跃避开。"
      end

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-200"}, {"neili", "-400"}], "assign_refs": [{"ap", "sword"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2 + random(2));", "target->start_busy(1);"], "level_gates": [{"force", "400"}, {"xuantie-jian", "200"}], "map_gates": [{"sword", "xuantie-jian"}], "remote_damage": true, "resource_gates": [{"neili", "1000"}], "set_flags": [{"value", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DONG "「" HIG "大江东去" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon, weapon_t;
  #         int damage;
  #         int ap, dp;
  #         string wp, msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuantie-jian/dong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DONG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" DONG "。\n");
  # 
  #         if ((int)me->query_skill("force") < 400)
  #                 return notify_fail("你的内功火候不够，难以施展" DONG "。\n");
  # 
  #         wp = weapon->name();
  # 
  #         if ((int)me->query_skill("xuantie-jian", 1) < 200)
  #                 return notify_fail("你的玄铁剑法不够娴熟，难以施展" DONG "。\n");
  # 
  #         if ((int)weapon->query_weight() < 25000
  #             && ! weapon->is_item_make())
  #                 return notify_fail("你手中的" + wp + "分量不够，难以施展" DONG "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在的内力不足，难以施展" DONG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "xuantie-jian")
  #                 return notify_fail("你没有激发玄铁剑法，难以施展" DONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "暗自凝神，顿时一股气劲由身后澎湃迸发，接着单"
  #               "手一振，手中" + wp + HIW "\n随即横空卷出，激得周围尘沙腾起"
  #               "，所施正是玄铁剑法「" HIG "大江东去" HIW "」。\n"NOR;
  # 
  #         me->start_busy(2 + random(2));
  # 
  #         ap = me->query_skill("sword") + me->query_str() * 5;
  #         dp = target->query_skill("force") + target->query_str() * 5;
  #         weapon_t = target->query_temp("weapon");
  # 
  #         if (weapon_t && random(2) && weapon->query_weight() > 25000 &&
  #             (!weapon_t->is_item_make() || weapon_t->query("skill_type") != "hammer"))
  #         {
  #                 msg += HIR "$n" HIR "只觉得一股大力传来，手中" + weapon_t->name() +
  #                        HIR "再也拿持不住，脱手而出！\n" NOR;
  #                 me->add("neili", -120);
  #                 weapon_t->move(environment(me));
  #                 weapon_t->set("no_wield", weapon_t->name() + "已经碎掉了，没法装备了。\n");
  #                 weapon_t->set_name("碎掉的" + weapon_t->name());
  #                 weapon_t->set("value", 0);
  #         }
  # 
  #         if (me->query("character") == "光明磊落" || me->query("character")=="国土无双" )
  #                 ap += ap / 5;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 target->start_busy(1);
  #                 damage = ap + random(ap);
  #                 me->add("neili", -400);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 120,
  #                                            HIR "结果$n" HIR "奋力招架，却被$N" HIR
  #                                            "这一剑震的飞起，口中鲜血狂吐不止！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "看破了$N"
  #                        CYN "的企图，急忙斜跃避开。\n"NOR;
  #                 me->add("neili", -200);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
