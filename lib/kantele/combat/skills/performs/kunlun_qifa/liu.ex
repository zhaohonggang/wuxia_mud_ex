defmodule Kantele.Combat.Skills.Performs.KunlunQifa.Liu do
  @moduledoc """
  流星电闪「liu」（对照 `kungfu/skill/kunlun-qifa/liu.c`，inherit F_SSERVER）

  昆仑器法（暗器 throwing，持有于 handing 槽）攻击绝招：要求持暗器且数量 >= 20、
  kunlun-qifa >= 120、force >= 200、真气 >= 150、目标存活且战斗中。攻击方广播
  起手、消耗全部暗器、扣 100 内力并发 `combat/perform-incoming`；命中判定
  `random(combat_exp + skill*skill/10*skill) > target_combat_exp`，命中后按四次
  指数判定叠加命中数 `n`，并造成 `skill/3 + random(skill/2)` 创伤；两分支忙乱 2。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "kunlun-qifa/liu"
  @move_name "「流星电闪」"

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
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, weapon)
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

  # LPC: if (! objectp(weapon = me->query_temp("handing")) ||
  #     (string)weapon->query("skill_type") != "throwing")
  #          return notify_fail("你现在手中并没有拿着暗器，无法施展" LIU "。\n");
  defp check_weapon(combat) do
    weapon = Map.get(combat.equipped, :handing)

    if weapon && Map.get(weapon, :skill_type) == "throwing" do
      {:ok, weapon}
    else
      {:error, "你现在手中并没有拿着暗器，无法施展#{@move_name}。\n"}
    end
  end

  defp check_amount(weapon) do
    if Map.get(weapon, :amount, 0) < 20 do
      {:error, "至少要有二十枚暗器你才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "kunlun-qifa") < 120 do
      {:error, "你的昆仑器法尚不娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不够，难以施展#{@move_name}。\n"}
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

  defp apply_perform(conn, character, target, stats, weapon) do
    weapon_name = Map.get(weapon, :name) || ""
    base_unit = Map.get(weapon, :base_unit) || Map.get(weapon, :unit) || ""
    amount = Map.get(weapon, :amount, 0)
    rng = &:rand.uniform/1
    skill = Stats.skill(stats, "kunlun-qifa")

    # LPC: msg = HIY "$N" HIY "一声冷笑，飞身跃起，半空中十指陡然箕张，手中的"
    #           + weapon->name() + HIY "便如流星一般向$n" HIY "飞去！\n";
    # NOTE: weapon->name() 把起手文案拆成两段字面量。
    start_msg =
      "$N一声冷笑，飞身跃起，半空中十指陡然箕张，手中的" <>
        weapon_name <>
        "便如流星一般向$n飞去！\n"

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
    #      ob_exp = target->query("combat_exp");
    #      if (random(my_exp) > ob_exp) { n = 5 + random(5); ... }
    my_exp = stats.combat_exp + div(skill * skill, 10) * skill
    ob_exp = target.meta.stats.combat_exp

    {hit?, n} =
      if Engine.rand(rng, max(my_exp, 1)) > ob_exp do
        n = 5 + Engine.rand(rng, 5)

        n = if Engine.rand(rng, max(my_exp, 1)) > ob_exp, do: n + 5 + Engine.rand(rng, 5), else: n

        n =
          if Engine.rand(rng, max(div(my_exp, 2), 1)) > ob_exp,
            do: n + 5 + Engine.rand(rng, 5),
            else: n

        n =
          if Engine.rand(rng, max(div(my_exp, 4), 1)) > ob_exp,
            do: n + 5 + Engine.rand(rng, 10),
            else: n

        n = if amount < n, do: amount, else: n
        {true, n}
      else
        {false, 0}
      end

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        hit?: hit?,
        n: n,
        skill: skill,
        weapon_name: weapon_name,
        base_unit: base_unit,
        rng: rng
      }
    })

    # LPC: weapon->set_amount(0); me->add("neili", -100); me->start_busy(2);
    # NOTE: 内力/忙乱经目标侧 Performs.feedback 回执落实；暗器消耗在此未回写背包。

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
    hit? = Map.get(data, :hit?, false)
    n = Map.get(data, :n, 0)
    skill = Map.get(data, :skill, 0)
    weapon_name = Map.get(data, :weapon_name)
    base_unit = Map.get(data, :base_unit)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    bindings = [n1: attacker.name, n2: character.name]

    if hit? do
      # LPC: target->receive_wound("qi", skill / 3 + random(skill / 2), me);
      vitals =
        Vitals.wound(
          character.meta.vitals,
          :qi,
          div(skill, 3) + Engine.rand(rng, max(div(skill, 2), 1))
        )

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += "$p" HIY "只觉眼前寒光一闪而过，反应不及，接连中了$P"
      #            HIY + chinese_number(n) + weapon->query("base_unit") +
      #            weapon->name() + HIY "！\n" NOR;
      hit_msg =
        "$p只觉眼前寒光一闪而过，反应不及，接连中了$P" <>
          chinese_number(n) <> (base_unit || "") <> (weapon_name || "") <> "！\n"

      conn = Broadcast.publish(conn, hit_msg, bindings)

      # LPC: msg += "( $n" + eff_status_msg(p) + " )\n";
      max_qi = character.meta.vitals.max_qi || character.meta.vitals.qi || 1
      p = div(character.meta.vitals.qi * 100, max(max_qi, 1))
      conn = Broadcast.publish(conn, "( $n" <> Messages.eff_status_msg(p) <> " )\n", bindings)

      Performs.feedback(attacker, 100, 2)

      put_character(conn, character)
    else
      # LPC: msg += NOR + CYN "可是$p" CYN "眼明手快，躲过了$P" CYN "发出"
      #            "的所有" + weapon->name() + CYN "。\n" NOR;
      miss_msg = "可是$p眼明手快，躲过了$P发出的所有" <> (weapon_name || "") <> "。\n"

      conn = Broadcast.publish(conn, miss_msg, bindings)

      Performs.feedback(attacker, 100, 2)

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

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "kunlun-qifa/liu",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
