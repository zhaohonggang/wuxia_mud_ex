defmodule Kantele.Combat.Skills.Performs.FumoZhang.Lun do
  @moduledoc """
  风火轮「lun」（对照 `kungfu/skill/fumo-zhang/lun.c`，inherit F_SSERVER）

  二十四路伏魔杖（棍 staff）攻击绝招：要求内力 >= 300、内功 force >= 150、
  fumo-zhang >= 120、棍已激发映射；按 staff 与 parry 判定命中（外伤 30%）。
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

  @perform_id "fumo-zhang/lun"
  @move_name "「风火轮」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
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

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "fumo-zhang") < 120 do
      {:error, "你二十四路伏魔杖火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "fumo-zhang" do
      :ok
    else
      {:error, "你没有激发二十四路伏魔杖，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

    # LPC: msg = HIW "$N" HIW "一声暴喝，手中" + weapon->name() +
    #           HIW "狂舞，残影化作无数大圈，宛若" HIR "风火轮"
    #           HIW "般铺天盖地卷向$n" HIW "。\n" NOR;
    # NOTE: weapon->name() 将起始文案拆成两段字面量。风火轮 在第二段内。
    p1 = "$N一声暴喝，手中"
    p2 = "狂舞，残影化作无数大圈，宛若风火轮般铺天盖地卷向$n。"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "staff")
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
      # LPC: damage = ap + random(ap / 2);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #        HIR "$n" HIR "完全无法看清招中虚实，只"
      #        "听「砰砰砰」几声，已被$N" HIR "击中数"
      #        "杖，呕血连连！\n" NOR);
      #      me->start_busy(3); me->add("neili", -150);
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 30, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "$n完全无法看清招中虚实，只听「砰砰砰」几声，已被$N击中数杖，呕血连连！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 150, 3)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$n" CYN "奋力招架，左闪右避，好不容"
      #            "易抵挡住了$N" CYN "的攻击。\n" NOR;
      #      me->start_busy(4); me->add("neili", -80);
      miss_msg = "可是$n奋力招架，左闪右避，好不容易抵挡住了$N的攻击。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 80, 4)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
