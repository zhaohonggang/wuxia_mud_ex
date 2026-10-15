defmodule Kantele.Combat.Skills.Performs.DaliChu.Hong do
  @moduledoc """
  轰雷万钧「hong」（对照 `kungfu/skill/dali-chu/hong.c`，inherit F_SSERVER）

  无上大力杵（锤 hammer）攻击绝招：要求真气 >= 200、max_neili >= 800、
  内功 force >= 120、dali-chu >= 80、锤已激发映射；按 hammer 与 force
  判定命中（外伤 55%）。
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

  @perform_id "dali-chu/hong"
  @move_name "「轰雷万钧」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
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

    if weapon && Map.get(weapon, :skill_type) == "hammer" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "hammer") == "dali-chu" do
      :ok
    else
      {:error, "你没有激发无上大力杵，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "dali-chu") < 80 do
      {:error, "你无上大力杵火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 800 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
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

    # LPC: msg = HIR "$N" HIR "舞动手中" + wp + HIR "，一招「" HIY "轰雷万钧"
    #           HIR "」挟着震天撞击之声朝$n" HIR "当头砸下！\n" NOR;
    # NOTE: wp (= weapon->name()) 把起始文案拆成两段字面量。
    p1 = "$N舞动手中"
    p2 = "，一招「轰雷万钧」挟着震天撞击之声朝$n当头砸下！\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "hammer")
    dp = Stats.skill(target.meta.stats, "force")

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
      # LPC: damage = ap/3 + random(ap/2);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #        HIR "$n" HIR "见$N" HIR "来势汹涌，心"
      #        "知不妙，可已然不及躲避，被这锤击中胸"
      #        "口，吐血连连。\n" NOR);
      #      me->start_busy(3); me->add("neili", -150);
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 55, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "$n见$N来势汹涌，心知不妙，可已然不及躲避，被这锤击中胸口，吐血连连。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 150, 3)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "早知$P"
      #            CYN "有此一着，当即巧妙招架，格挡开来。\n"NOR;
      #      me->start_busy(3); me->add("neili", -100);
      miss_msg = "可是$p早知$P有此一着，当即巧妙招架，格挡开来。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
