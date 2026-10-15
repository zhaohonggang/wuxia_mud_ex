defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Qian do
  @moduledoc """
  剑舞千秋「qian」（对照 `kungfu/skill/miaojia-jian/qian.c`）

  苗家剑法绝技：需持剑、苗家剑法>=160、内功>=220、max_neili>=1800、
  真气>=300、激发 sword 为苗家剑法、目标存活。命中判定
  `ap/2 + random(ap*2) > 目标parry`（ap = sword）：命中后
  `attack_time = 5 + random(ap/45)`（上限 8）、临时 `apply/attack += ap/10`；
  未命中则 `attack_time = 5`。连出 `attack_time` 击后扣
  `attack_time*25` 内力，忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - LPC 的 `attack_time` 次 `COMBAT_D->do_attack`（完整管线）折算为逐击命中
    判定 + 伤害（同 `biyan_dao/luo.ex`）；
  - `message_combatd` 的命中/失手引子在目标侧结算。
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

  @perform_id "miaojia-jian/qian"
  @move_name "「剑舞千秋」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon)
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_level(stats) do
    if Stats.skill(stats, "miaojia-jian") < 160 do
      {:error, "你苗家剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 220 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1800 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "miaojia-jian" do
      :ok
    else
      {:error, "你没有激发苗家剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    stats = character.meta.stats
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIY "$N" HIY "手中" + weapon->name()
    #           + HIY "一声龙吟，三十七势苗" "家剑连环施出，将$n" HIY "罩在剑光之中。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N手中" <> weapon_name <> "一声龙吟，三十七势苗家剑连环施出，将$n罩在剑光之中。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        sword: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :sword, 0), 1)
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap * 2) > dp) { count = ap / 10;
    #          me->add_temp("apply/attack", count); attack_time += random(ap / 45); }
    #      else { count = 0; }
    hit? = div(ap, 2) + Engine.rand(rng, ap * 2) > dp
    attack_time = if hit?, do: 5 + Engine.rand(rng, max(div(ap, 45), 1)), else: 5
    count = if hit?, do: div(ap, 10), else: 0

    conn =
      if hit? do
        Broadcast.publish(
          conn,
          "$p只见得剑光万道，顿时被$P凌厉的剑招攻得应接不暇，连连后退！\n",
          bindings
        )
      else
        Broadcast.publish(
          conn,
          "$n见$N剑势汹涌，霍霍剑光逼人而来，不敢大意，小心应付。\n",
          bindings
        )
      end

    attack_time = min(attack_time, 8)

    # LPC 连出 attack_time 击，每击 COMBAT_D->do_attack(me, target, weapon, 0)；
    # 期间 apply/attack += count（折算为每击 ap + count）。
    ap2 = ap + count

    damage =
      Enum.reduce(1..attack_time, 0, fn _i, acc ->
        if div(ap2, 2) + Engine.rand(rng, ap2) > dp do
          acc + div(ap2, 2) + Engine.rand(rng, max(div(ap2, 2), 1))
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -attack_time * 25); me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 25, 1 + Engine.rand(rng, max(attack_time, 1)))

    put_character(conn, character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "miaojia-jian/qian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
