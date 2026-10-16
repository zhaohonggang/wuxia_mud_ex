defmodule Kantele.Combat.Skills.Performs.DongyangDao.Zhan do
  @moduledoc """
  迎风一刀斩「zhan」（对照 `kungfu/skill/dongyang-dao/zhan.c`，inherit F_SSERVER）

  东洋刀法（刀 blade）攻击绝招：要求真气 >= 300、内功 force >= 120、
  dongyang-dao >= 70、持刀；按 blade 与 force 判定命中（外伤 55%）。
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

  @perform_id "dongyang-dao/zhan"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「迎风一刀斩」只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "dongyang-dao") < 70 do
      {:error, "你的东洋刀法不够娴熟，不会使用「迎风一刀斩」。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功修为不够高，难以运用「迎风一刀斩」。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，不能使用「迎风一刀斩」。\n"}
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

    # LPC: msg = HIC "\n$N" HIC "大喝一声，眼中凶光毕露，手中的" +
    #           weapon->name() + HIC "化作一道光弧直劈而下，正是扶桑密学「迎风一刀斩」。\n"NOR;
    # NOTE: weapon->name() 把起始文案拆成两段字面量。
    p1 = "\n$N大喝一声，眼中凶光毕露，手中的"
    p2 = "化作一道光弧直劈而下，正是扶桑密学「迎风一刀斩」。\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "blade")
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
      # LPC: damage = ap/2 + random(ap);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #        HIR "$n" HIR "只觉得脑中轰的一下，浑"
      #        "身血脉登时不畅，不禁“哇”的吐了一口鲜血。\n" NOR);
      #      me->start_busy(2); me->add("neili", -100);
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 55, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "$n只觉得脑中轰的一下，浑身血脉登时不畅，不禁“哇”的吐了一口鲜血。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += HIC "然而$p" HIC "运足中气，硬接下了这一刀，丝毫无伤。\n"NOR;
      #      me->start_busy(3); me->add("neili", -50);
      miss_msg = "然而$p运足中气，硬接下了这一刀，丝毫无伤。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 50, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
