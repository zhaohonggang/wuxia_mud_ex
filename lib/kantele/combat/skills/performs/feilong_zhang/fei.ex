defmodule Kantele.Combat.Skills.Performs.FeilongZhang.Fei do
  @moduledoc """
  龙飞势「fei」（对照 `kungfu/skill/feilong-zhang/fei.c`，inherit F_SSERVER）

  飞龙杖法（杖 staff）攻击绝招：要求真气 >= 500、max_neili >= 2500、
  内功 force >= 240、feilong-zhang >= 160、杖已激发映射；
  按 staff 与目标 dodge 判定命中。命中伤害 `ap/2 + random(ap/2)`，
  再 `+random(damage)`（外伤 55%）。命中后武器脱手飞出（LPC: `weapon->move`）。
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

  @perform_id "feilong-zhang/fei"
  @move_name "「龙飞势」"

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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "feilong-zhang") < 160 do
      {:error, "你飞龙杖法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "feilong-zhang" do
      :ok
    else
      {:error, "你没有激发飞龙杖法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 240 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 2500 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
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

    # LPC: msg = HIW "$N" HIW "嗔目大喝，将全身劲力运于右臂，掌中" + wn +
    #           HIW "顿时离手射出，朝$n" HIW "飞去！\n" NOR;
    # NOTE: wn 把起始文案拆成两段字面量。
    p1 = "$N嗔目大喝，将全身劲力运于右臂，掌中"
    p2 = "顿时离手射出，朝$n飞去！\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "staff")
    dp = Stats.skill(target.meta.stats, "dodge")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    # LPC: weapon->move(environment(me)); —— 武器脱手，TODO: 落点房间/物品迁移。
    _ = combat

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
    weapon_name = Map.get(data, :weapon_name)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 2 + random(ap / 2); damage += random(damage);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #        HIR "$n" HIR "只觉一股劲风袭到，闪避"
      #        "不及，那根" + wn + HIR "正好击中胸口"
      #        "，撞断数根肋骨。\n" NOR);
      #      me->start_busy(3); me->add("neili", -300);
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))
      damage = damage + Engine.rand(rng, max(damage, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 55, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # NOTE: "正好击中胸口" 与 "，撞断数根肋骨。" 在 C 中相邻（中间仅 HIY），
      #       合并为单一字面量；无额外 + 分隔。
      h1 = "$n只觉一股劲风袭到，闪避不及，那根"
      h2 = "正好击中胸口，撞断数根肋骨。\n"
      hit_msg = h1 <> (weapon_name || "") <> h2
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 300, 3)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "$n" CYN "见$N" CYN "气势如虹，不敢硬"
      #            "接，当即向后横移数尺，躲闪开来。\n" NOR;
      #      me->start_busy(4); me->add("neili", -200);
      miss_msg = "$n见$N气势如虹，不敢硬接，当即向后横移数尺，躲闪开来。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 200, 4)

      conn
      |> put_character(character)
    end
    |> then(fn conn ->
      # LPC: msg += HIY "只见那根" + wn + HIY "余势不尽，又向前飞出数"
      #            "丈，方才没入土中。\n" NOR;
      # NOTE: 该段位于 hit/miss 分支之后，无条件追加一次；wn 拆两段字面量。
      t1 = "只见那根"
      t2 = "余势不尽，又向前飞出数丈，方才没入土中。\n"
      tail_msg = t1 <> (weapon_name || "") <> t2
      Broadcast.publish(conn, tail_msg, n1: attacker.name, n2: character.name)
    end)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
