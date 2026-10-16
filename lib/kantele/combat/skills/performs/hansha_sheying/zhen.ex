defmodule Kantele.Combat.Skills.Performs.HanshaSheying.Zhen do
  @moduledoc """
  无影针「zhen」（对照 `kungfu/skill/hansha-sheying/zhen.c`）

  寒沙射影（暗器 throwing，持有于 handing 槽）攻击绝招：要求持暗器且数量 >= 10、
  hansha-sheying >= 120、force >= 150、真气 >= 150；消耗内力 100、暗器 10 枚，
  忙乱 2。命中判定 `random(combat_exp + skill*skill/10*skill) > target_combat_exp`，
  命中后按四次指数判定叠加命中数 `n`，并造成 `skill/2 + random(skill/2)` 外伤。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "hansha-sheying/zhen"
  @move_name "「无影针」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_amount(weapon),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, weapon, level)
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

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Map.get(combat.equipped, :handing)

    if weapon && Map.get(weapon, :skill_type) == "throwing" do
      {:ok, weapon}
    else
      {:error, "你现在手中并没有拿着暗器，难以施展#{@move_name}。\n"}
    end
  end

  defp check_amount(weapon) do
    if Map.get(weapon, :amount, 1) < 10 do
      {:error, "至少要有十枚暗器才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "hansha-sheying")

    if level < 120 do
      {:error, "你的含沙射影不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target), do: {:error, "对方都已经这样了，用不着这么费力吧？\n"}, else: :ok
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon, level) do
    weapon_name = Map.get(weapon, :name)
    base_unit = Map.get(weapon, :base_unit) || Map.get(weapon, :unit) || ""
    character = consume_darts(character, weapon)
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: msg= HIR "只听“飕飕飕飕”数声，一股劲风从$N" HIR "处激射而出，$N" HIR
    #          "手中" + weapon->name() + HIR "如烟雨般向$n" HIR "笼罩过去！\n";
    start_msg = "只听“飕飕飕飕”数声，一股劲风从$N处激射而出，$N手中" <> (weapon_name || "") <> "如烟雨般向$n笼罩过去！\n"

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        skill: level,
        combat_exp: stats.combat_exp,
        weapon_name: weapon_name,
        base_unit: base_unit,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> Broadcast.publish(start_msg, n1: character.name, n2: target.name)
    |> assign(:prompt, false)
  end

  defp consume_darts(character, weapon) do
    amount = Map.get(weapon, :amount, 1) - 10

    inventory =
      character.inventory
      |> Enum.reject(fn item -> item == weapon && amount < 1 end)
      |> Enum.map(fn item ->
        if item == weapon, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: item
      end)

    %{character | inventory: inventory}
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
    skill = Map.get(data, :skill, 0)
    weapon_name = Map.get(data, :weapon_name)
    base_unit = Map.get(data, :base_unit)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    my_exp = Map.get(data, :combat_exp, 0) + div(skill * skill, 10) * skill
    ob_exp = character.meta.stats.combat_exp
    bindings = [n1: attacker.name, n2: character.name]

    {hit?, n} =
      if Engine.rand(rng, max(my_exp, 1)) > ob_exp do
        n = 1 + Engine.rand(rng, 2)

        n = if Engine.rand(rng, max(my_exp, 1)) > ob_exp, do: n + 1 + Engine.rand(rng, 2), else: n

        n =
          if Engine.rand(rng, max(div(my_exp, 2), 1)) > ob_exp,
            do: n + 1 + Engine.rand(rng, 2),
            else: n

        n =
          if Engine.rand(rng, max(div(my_exp, 4), 1)) > ob_exp,
            do: n + 1 + Engine.rand(rng, 2),
            else: n

        {true, n}
      else
        {false, 0}
      end

    if hit? do
      vitals =
        Vitals.wound(
          character.meta.vitals,
          :qi,
          div(skill, 2) + Engine.rand(rng, max(div(skill, 2), 1))
        )

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += "结果$p" HIR "反应不及，中了$P" HIR + chinese_number(n) +
      #            weapon->query("base_unit") + weapon->name() + HIR "！\n" NOR;
      hit_msg =
        "结果$p反应不及，中了$P" <> chinese_number(n) <> (base_unit || "") <> (weapon_name || "") <> "！\n"

      conn = Broadcast.publish(conn, hit_msg, bindings)

      # LPC: me->add("neili", -100); me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      put_character(conn, character)
    else
      # LPC: msg += NOR + CYN "可是$p" CYN "躲过了$P" CYN "发出的所有" +
      #            weapon->name() + NOR + CYN "。\n" NOR;
      miss_msg = "可是$p躲过了$P发出的所有" <> (weapon_name || "") <> "。\n"
      conn = Broadcast.publish(conn, miss_msg, bindings)

      Performs.feedback(attacker, 0, 2)

      conn
    end
  end

  # LPC: chinese_number(n) —— 用码点构造避免在源码中留下中文字面量（1..9）。
  defp chinese_number(n) when is_integer(n) and n >= 1 and n <= 9 do
    <<0x4E00 + n - 1::utf8>>
  end

  defp chinese_number(n), do: Integer.to_string(n)

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
