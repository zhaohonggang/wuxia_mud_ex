defmodule Kantele.Combat.Skills.Performs.DagouBang.Chuo do
  @moduledoc """
  戳字诀「chuo」（对照 `kungfu/skill/dagou-bang/chuo.c`，inherit F_SSERVER）

  打狗棒法（棍 staff）攻击绝招：要求内力 >= 200、内功 force >= 160、
  dagou-bang >= 100、棍已激发映射；按 staff+直觉 与 dodge+直觉 判定命中
  （外伤 50%）。
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

  @perform_id "dagou-bang/chuo"
  @move_name "「戳字诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
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

  defp check_skill_level(stats) do
    if Stats.skill(stats, "dagou-bang") < 100 do
      {:error, "你打狗棒法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "dagou-bang" do
      :ok
    else
      {:error, "你没有激发打狗棒法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 160 do
      {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
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
    # LPC: msg = HIG "$N" HIG "使出打狗棒法「" HIR "戳" HIG "」字诀，单"
    #           "手一振，霎时棒影窜动，疾刺$n" HIG "胸前要穴。\n" NOR;
    # NOTE: 全段相邻拼接，为单一字面量（无 +、无 weapon->name()）。
    start_msg = "$N使出打狗棒法「戳」字诀，单手一振，霎时棒影窜动，疾刺$n胸前要穴。\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "staff") + Stats.skill(stats, "martial-cognize")
    dp = Stats.skill(target.meta.stats, "dodge") + Stats.skill(target.meta.stats, "martial-cognize")

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
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #        HIR "$n" HIR "全然无法勘破$N" HIR "的"
      #        "精妙招式，胸口一麻，射出一柱鲜血！\n" NOR);
      #      me->start_busy(2); me->add("neili", -100);
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 50, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "$n全然无法勘破$N的精妙招式，胸口一麻，射出一柱鲜血！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可$n" CYN "全神防御，不露半点破绽，使得$N"
      #            CYN "这招无功而返。\n" NOR;
      #      me->start_busy(3); me->add("neili", -50);
      miss_msg = "可$n全神防御，不露半点破绽，使得$N这招无功而返。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 50, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
