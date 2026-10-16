defmodule Kantele.Combat.Skills.Performs.EmeiJian.Xian do
  @moduledoc """
  佛光初现「xian」（对照 `kungfu/skill/emei-jian/xian.c`，inherit F_SSERVER）

  峨嵋剑法（剑 sword）攻击绝招：要求真气 >= 100、emei-jian >= 60、剑已激发映射；
  按 `sword + mahayana` 与目标 `parry` 判定命中，命中伤害
  `damage = ap/2 + random(ap/3)`（外伤 40%）。
  注意：起始文案写「峨眉剑法」，门禁写「峨嵋剑法」（LPC 原本即有差异）。
  消耗内力 75、忙乱 3（命中/落空均扣除）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "emei-jian/xian"
  @move_name "「佛光初现」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "emei-jian") < 60 do
      {:error, "你的峨嵋剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "emei-jian" do
      :ok
    else
      {:error, "你没有激发峨嵋剑法，无法施展#{@move_name}。\n"}
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIY "$N" HIY "跨步上前，手中" + weapon->name() +
    #           HIY "将峨眉剑法运转如飞，剑光霍霍径直逼向$n" HIY "。\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段字面量（“峨眉剑法”与原版一致）。
    p1 = "$N跨步上前，手中"
    p2 = "将峨眉剑法运转如飞，剑光霍霍径直逼向$n。\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: me->add("neili", -75);（无条件，先于命中判定）
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 75}
    character = %{character | meta: %{character.meta | vitals: vitals}}
    # LPC: me->start_busy(3);（无条件）
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC: ap = me->query_skill("sword") + me->query_skill("mahayana", 1);
    #      dp = target->query_skill("parry");
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "mahayana")
    dp = Stats.skill(target.meta.stats, "parry")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 2 + random(ap / 3);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                 (: final, me, target, damage :));
      # final(): return HIR "顿时只听“嗤”的一声，$n" HIR "稍个不慎，"
      #                 "被这一剑划得鲜血淋漓。\n" NOR;
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 3), 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 40, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "顿时只听“嗤”的一声，$n稍个不慎，被这一剑划得鲜血淋漓。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      conn
      |> put_character(character)
    else
      # LPC: msg += HIC "可$n" HIC "却是镇定逾恒，一丝不乱，"
      #            "全神将此招化解开来。\n" NOR;
      miss_msg = "可$n却是镇定逾恒，一丝不乱，全神将此招化解开来。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
