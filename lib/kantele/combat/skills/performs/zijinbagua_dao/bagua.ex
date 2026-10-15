defmodule Kantele.Combat.Skills.Performs.ZijinbaguaDao.Bagua do
  @moduledoc """
  perform「bagua」（source zijinbagua-dao/bagua.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zijinbagua-dao/bagua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zijinbagua-dao")
    blade = Stats.skill(stats, "blade")
    weapon = Combat.weapon(combat)
    weapon_name = Map.get(weapon, :name, "")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          blade: blade,
          weapon_name: weapon_name,
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
      Stats.skill(stats, "force") < 220 -> {:error, "你的内功火候不够！\n"}
      Stats.skill(stats, "zijinbagua-dao") < 200 -> {:error, "你的紫金八卦刀还不到家，无法使用「八卦阵芒」！\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "zijinbagua-dao" -> {:error, "你没有激发紫金八卦刀，无法使用「八卦阵芒」！\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "你的内力修为不够。\n"}
      vitals.neili < 400 -> {:error, "你的真气不够！\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) == nil -> {:error, "你的兵器不对。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: msg = MAG "$N" MAG "一声暴喝，手中的" + weapon->name() +
    #           MAG "刀芒陡长，顿时只见万股凌厉的刀芒按照八卦阵的"
    #           "方位直涌$n" MAG "！\n\n" NOR;
    #      me->add("neili", -300);   // 无条件，直接在攻击方侧落账
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = Map.get(weapon, :name, "")
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 300, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      Broadcast.publish(
        conn,
        "$N一声暴喝，手中的" <> weapon_name <> "刀芒陡长，顿时只见万股凌厉的刀芒按照八卦阵的方位直涌$n！\n\n",
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
      [] -> {:error, "「八卦阵芒」只能对战斗中的对手使用。\n"}
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
    blade = max(Map.get(data, :blade, 0), 1)
    level = Map.get(data, :level, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
    dp = div(Stats.skill(stats, "parry"), 2)
    hit? = Engine.rand(rng, blade) > dp

    conn =
      if hit? do
        # LPC: msg += HIR "$n" HIR "见来招实在是变幻莫测，不由得心"
        #                 "生惧意，招式登时出了破绽！\n" NOR;
        #      count = me->query_skill("zijinbagua-dao", 1) / 6;
        Broadcast.publish(
          conn,
          Messages.interpolate("$n见来招实在是变幻莫测，不由得心生惧意，招式登时出了破绽！\n", bindings)
        )
      else
        # LPC: msg += HIY "$n" HIY "心底微微一惊，打起精神小心接招。\n" NOR;
        #      count = 0;
        Broadcast.publish(
          conn,
          Messages.interpolate("$n心底微微一惊，打起精神小心接招。\n", bindings)
        )
      end

    # LPC: for (i = 0; i < 5 + random(3); i++) { ... COMBAT_D->do_attack(me, target, weapon, 0); }
    #      期间 apply/attack += count（折算为每击 blade + count）。
    count = if hit?, do: div(level, 6), else: 0
    ap2 = blade + count
    attack_time = 5 + Engine.rand(rng, 3)

    damage =
      Enum.reduce(1..attack_time, 0, fn _i, acc ->
        if div(ap2, 2) + Engine.rand(rng, ap2) > dp do
          acc + div(ap2, 2) + Engine.rand(rng, max(div(ap2, 2), 1))
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
    #      me->add_temp("apply/attack", -count);
    #      me->start_busy(1 + random(6));
    if Engine.rand(rng, 3) == 1 and character.meta.combat.busy == 0 do
      combat = Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | combat: combat}}
    end

    Performs.feedback(attacker, 300, 1 + Engine.rand(rng, 6))
    put_character(conn, character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack"], "assign_refs": [{"count", "zijinbagua-dao"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"force", "220"}, {"zijinbagua-dao", "200"}], "map_gates": [{"blade", "zijinbagua-dao"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "400"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // bagua.c 八卦阵
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「八卦阵芒」只能对战斗中的对手使用。\n");
  #  
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你的兵器不对。\n");
  # 
  #         if ((int)me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为不够。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #         if ((int)me->query_skill("force") < 220)
  #                 return notify_fail("你的内功火候不够！\n");
  # 
  #         if ((int)me->query_skill("zijinbagua-dao", 1) < 200)
  #                 return notify_fail("你的紫金八卦刀还不到家，无法使用「八卦阵芒」！\n");
  # 
  #         if (me->query_skill_mapped("blade") != "zijinbagua-dao")
  #                 return notify_fail("你没有激发紫金八卦刀，无法使用「八卦阵芒」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = MAG "$N" MAG "一声暴喝，手中的" + weapon->name() +
  #               MAG "刀芒陡长，顿时只见万股凌厉的刀芒按照八卦阵的"
  #               "方位直涌$n" MAG "！\n\n" NOR;
  # 
  #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
  #         {
  #                 msg += HIR "$n" HIR "见来招实在是变幻莫测，不由得心"
  #                        "生惧意，招式登时出了破绽！\n" NOR;
  #                 count = me->query_skill("zijinbagua-dao", 1) / 6;
  #         } else
  #         {
  #                 msg += HIY "$n" HIY "心底微微一惊，打起精神小心接招。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -300);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 5 + random(3) ; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(6));
  #         return 1;
  # }
end
