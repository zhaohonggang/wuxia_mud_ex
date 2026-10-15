defmodule Kantele.Combat.Skills.Performs.ZileiJian.Luo do
  @moduledoc """
  perform「落雷式」（source zilei-jian/luo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zilei-jian/luo"
  @move_name "「落雷式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zilei-jian")
    ap = Stats.skill(stats, "sword")
    damage = (ap + Engine.rand(rng, div(ap, 2)))

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
          damage: damage,
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
      Stats.skill(stats, "zilei-jian") < 120 -> {:error, "你紫雷剑法不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 150 -> {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "zilei-jian" -> {:error, "你没有激发紫雷剑法，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) == nil -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: msg = HIW "\n$N" HIW "将" + wn + HIW "斜指长空，猛地飞身跃起，"
    #           + wn + HIW "长响一声，寒光闪闪，犹如一道闪电劈空而下，一招"
    #           "「" HIG "落雷式" HIW "」已使出，以千军不可挡之势袭向$n" HIW
    #           "。" NOR;
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = Map.get(weapon, :name, "")

    conn =
      Broadcast.publish(
        conn,
        "\n$N将" <>
          weapon_name <>
          "斜指长空，猛地飞身跃起，" <>
          weapon_name <>
          "长响一声，寒光闪闪，犹如一道闪电劈空而下，一招「落雷式」已使出，以千军不可挡之势袭向$n。",
        n1: character.name,
        n2: target_name(character)
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target_name(character) do
    case character.meta.combat.enemies do
      [enemy | _] -> enemy.name
      [] -> ""
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「落雷式」只能在战斗中对对手使用。\n"}
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
    stats = character.meta.stats
    ap = max(Map.get(data, :ap, 0), 1)
    damage = Map.get(data, :damage, 0)
    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    bindings = [n1: attacker.name, n2: character.name]

    if hit do
      # LPC: msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #          HIR "$n" HIR "只见一道电光从半空袭来，"
      #          "心中惊骇不已，但鲜血已从$n胸口喷出。\n" NOR);
      #      me->start_busy(2 + random(4)); me->add("neili", -200);
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("$n只见一道电光从半空袭来，心中惊骇不已，但鲜血已从$n胸口喷出。\n", bindings)
        )

      Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 4))
      put_character(conn, character)
    else
      # LPC: msg = CYN "然而$n" CYN "眼明手快，侧身一跳"
      #                 "躲过$N" CYN "这一剑。\n" NOR;
      #      me->start_busy(2); me->add("neili", -180);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("然而$n眼明手快，侧身一跳躲过$N这一剑。\n", bindings)
        )

      Performs.feedback(attacker, 180, 2)
      conn
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}, {"neili", "-200"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(4));", "me->start_busy(2);"], "level_gates": [{"force", "150"}, {"zilei-jian", "120"}], "map_gates": [{"sword", "zilei-jian"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LUO "「" HIW "落雷式" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, wn;
  #         object weapon;
  #         int ap, dp;
  # 
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/zilei-jian/luo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LUO "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" LUO "。\n");
  # 
  #         if ((int)me->query_skill("zilei-jian", 1) < 120)
  #                 return notify_fail("你紫雷剑法不够娴熟，难以施展" LUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "zilei-jian")
  #                 return notify_fail("你没有激发紫雷剑法，难以施展" LUO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" LUO "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在的真气不够，难以施展" LUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIW "\n$N" HIW "将" + wn + HIW "斜指长空，猛地飞身跃起，"
  #               + wn + HIW "长响一声，寒光闪闪，犹如一道闪电劈空而下，一招"
  #               "「" HIG "落雷式" HIW "」已使出，以千军不可挡之势袭向$n" HIW
  #               "。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                           HIR "$n" HIR "只见一道电光从半空袭来，"
  #                                           "心中惊骇不已，但鲜血已从$n胸口喷出。\n"
  #                                           NOR);
  #              me->start_busy(2 + random(4));
  #              me->add("neili", -200);
  #         } else
  #         {
  #              msg = CYN "然而$n" CYN "眼明手快，侧身一跳"
  #                       "躲过$N" CYN "这一剑。\n" NOR;
  # 
  #              me->start_busy(2);
  #              me->add("neili", -180);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
