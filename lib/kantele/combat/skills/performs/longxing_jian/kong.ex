defmodule Kantele.Combat.Skills.Performs.LongxingJian.Kong do
  @moduledoc """
  金龙疾空「kong」（对照 `kungfu/skill/longxing-jian/kong.c`，inherit F_SSERVER）

  龙形剑法（剑 sword）多段攻击绝招：要求内力 >= 250、longxing-jian >= 160、
  剑已激发映射；按 sword 与 parry 判定命中，命中后多轮 do_attack
  （attack_time = 7，命中再加 random(ap/45)，上限 10，apply/attack 临时加成）。
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

  @perform_id "longxing-jian/kong"
  @move_name "「金龙疾空」"

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
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "longxing-jian") < 160 do
      {:error, "你的龙形剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "longxing-jian" do
      :ok
    else
      {:error, "你没有激发龙形剑法，难以施展#{@move_name}。\n"}
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

    # LPC: msg = HIY "$N" HIY "一声清啸，手中" + weapon->name() +
    #           HIY "龙吟不定，划向虚空，刹那间，一道金光疾射，"
    #           HIY "犹如一条金龙腾越在半空，猛地射向$n" HIY "。\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段独立字面量。
    p1 = "$N一声清啸，手中"
    p2 = "龙吟不定，划向虚空，刹那间，一道金光疾射，犹如一条金龙腾越在半空，猛地射向$n。\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "sword")
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

    # LPC: attack_time = 7 + random(ap/45)（上限 10），命中后循环 do_attack
    #      并临时 add_temp("apply/attack", count = ap/6)。
    # TODO: 多段攻击循环（Engine.attack_round）及 apply/attack 临时加成跨进程补全。
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: msg += HIR "结果$p" HIR "被$P" HIR
      #            "攻了个措手不及，连连后退不暇！\n" NOR;
      hit_msg = "结果$p被$P攻了个措手不及，连连后退不暇！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 1)

      conn
      |> put_character(character)
    else
      # LPC: msg += HIC "$n" HIC "见$N" HIC "这几剑并无破绽"
      #            "，不敢大意，小心应付。\n" NOR;
      miss_msg = "$n见$N这几剑并无破绽，不敢大意，小心应付。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 1)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
