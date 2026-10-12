defmodule Kantele.Combat.Skills.Performs.RouyunJian.Tao do
  @moduledoc """
  perform「三环套月」（source rouyun-jian/tao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "rouyun-jian/tao"
  @move_name "「三环套月」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "rouyun-jian")

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
      Stats.skill(stats, "rouyun-jian") < 140 -> {:error, "你的柔云剑法修为不够，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 180 -> {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "dodge") < 180 -> {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "rouyun-jian" -> {:error, "你没有激发柔云剑法，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    weapon = Combat.weapon(character.meta.combat)

    cond do
      weapon == nil or weapon.skill_type != "sword" -> {:error, "你使用的武器不对。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # 攻击方消耗/Busy + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1 + :rand.uniform(3))
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn =
      Broadcast.publish(
        conn,
        "$N使出柔云剑法「三环套月」，一招之中另蕴三招，铺天盖地罩向$n！",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「三环套月」只能在战斗中对对手使用。\n"}
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

  defp do_resolve_incoming(conn, character, _attacker, data) do
    # LPC: 3 次 do_attack，逐次累加 apply/attack(+40/+60/+80) 与 apply/damage(+10/+30/+50)
    # 折算：三次攻击命中累计伤害（附加攻击/伤害加成并入每次判定）
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    attack_bonus = [40, 100, 180]
    damage_bonus = [10, 40, 90]

    damage =
      Enum.reduce(0..2, 0, fn i, damage_acc ->
        hit_ap = ap + Enum.at(attack_bonus, i)

        if hit_ap + Engine.rand(rng, ap) > dp do
          damage_acc + ap + Enum.at(damage_bonus, i) + Engine.rand(rng, ap)
        else
          damage_acc
        end
      end)

    character =
      if damage > 0 do
        vitals = Vitals.damage(character.meta.vitals, :qi, damage)
        %{character | meta: %{character.meta | vitals: vitals}}
      else
        character
      end

    conn
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1 + random(3));"], "level_gates": [{"dodge", "180"}, {"force", "180"}, {"rouyun-jian", "140"}], "map_gates": [{"sword", "rouyun-jian"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define TAO "「" HIC "三环套月" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/rouyun-jian/tao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail(TAO "只能在战斗中对对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("你使用的武器不对。\n");
  # 
  #     if (me->query_skill("rouyun-jian", 1) < 140)
  #         return notify_fail("你的柔云剑法修为不够，难以施展" TAO "。\n");
  # 
  #     if (me->query_skill("force") < 180)
  #         return notify_fail("你的内功修为不够，难以施展" TAO "。\n");
  # 
  #     if (me->query_skill("dodge") < 180)
  #         return notify_fail("你的轻功修为不够，难以施展" TAO "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，难以施展" TAO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "rouyun-jian")
  #                 return notify_fail("你没有激发柔云剑法，难以施展" TAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "使出柔云剑法「三环套月」，一招之中另蕴三招，铺天"
  #               "盖地罩向$n" HIC "！\n" NOR;
  #         message_combatd(msg, me, target);
  #     me->add("neili", -150);
  # 
  #         me->add_temp("apply/attack", 40);
  #         me->add_temp("apply/damage", 10);
  #           COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", 60);
  #         me->add_temp("apply/damage", 30);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", 80);
  #         me->add_temp("apply/damage", 50);
  #     COMBAT_D->do_attack(me, target, weapon, 0);
  # 
  #         me->add_temp("apply/attack", -180);
  #         me->add_temp("apply/damage", -90);
  #     me->start_busy(1 + random(3));
  #     return 1;
  # }
end
