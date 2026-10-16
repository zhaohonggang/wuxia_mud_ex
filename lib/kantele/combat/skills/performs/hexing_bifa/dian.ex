defmodule Kantele.Combat.Skills.Performs.HexingBifa.Dian do
  @moduledoc """
  内点乾坤「dian」（对照 `kungfu/skill/hexing-bifa/dian.c`，inherit F_SSERVER）

  鹤形笔法攻击绝招：要求持 dagger 类武器、hexing-bifa >= 100、
  mapped("dagger") == "hexing-bifa"、真气 >= 300。攻击方广播起手式并发
  `combat/perform-incoming`，目标侧先按 `ap/2 + rand(ap) > dp`（ap=dagger，
  dp=dodge）追加连击数，再最多连击 8 次；忙乱 `1 + rand(attack_time)`，
  攻击方按 `attack_time * 30` 扣内力。
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

  @perform_id "hexing-bifa/dian"
  @move_name "「内点乾坤」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, weapon_name)
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #     || (string)weapon->query("skill_type") != "dagger")
  #          return notify_fail("你所使用的武器不对，难以施展" DIAN "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "dagger" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("hexing-bifa", 1) < 100)
  #          return notify_fail("你的鹤形笔法不够娴熟，难以施展" DIAN "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "hexing-bifa") < 100 do
      {:error, "你的鹤形笔法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("dagger") != "hexing-bifa")
  #          return notify_fail("你没有激发鹤形笔法，难以施展" DIAN "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "dagger") == "hexing-bifa" do
      :ok
    else
      {:error, "你没有激发鹤形笔法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 300)
  #          return notify_fail("你目前的真气不够，难以施展" DIAN "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你目前的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target),
      do: :ok,
      else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon_name) do
    ap = Stats.skill(stats, "dagger")

    # LPC: msg = HIW "\n$N" HIW "身法陡快，手中" + weapon->name() + HIW "一扬，"
    #           "施出绝招「" HIM "内点乾坤" HIW "」，猛然间，" + weapon->name() + HIW
    #           "连连点向$n" HIW "周身要穴。\n" NOR;
    # NOTE: weapon->name() 把起手文案拆成三段字面量。
    opening =
      "$N身法陡快，手中" <>
        weapon_name <>
        "一扬，施出绝招「内点乾坤」，猛然间，" <>
        weapon_name <> "连连点向$n周身要穴。\n"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap, rng: &:rand.uniform/1}
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "dodge")

    # LPC: attack_time = 4; if (ap / 2 + random(ap) > dp) attack_time += random(ap / 40);
    #      if (attack_time > 8) attack_time = 8;
    attack_time =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
        4 + Engine.rand(rng, max(div(ap, 40), 1))
      else
        4
      end

    attack_time = min(attack_time, 8)

    character =
      Enum.reduce(1..max(attack_time, 1), character, fn _, ch ->
        # 逐击按空手/兵刃伤害结算（无额外文案，对齐 LPC do_attack）
        damage = div(ap, 4) + Engine.rand(rng, max(div(ap, 2), 1))

        vitals =
          ch.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 10, 100))

        %{ch | meta: %{ch.meta | vitals: vitals}}
      end)

    # LPC: me->add("neili", -attack_time * 30); me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 30, 1 + Engine.rand(rng, max(attack_time, 1)))

    put_character(conn, character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "hexing-bifa/dian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
