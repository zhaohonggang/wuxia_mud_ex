defmodule Kantele.Combat.Skills.Performs.LutouZhang.Tong do
  @moduledoc """
  通天彻地「tong」（对照 `kungfu/skill/lutou-zhang/tong.c`）

  鹿头杖法绝技：需持杖、内功>=140、真气>=200、鹿头杖法>=100、激发 staff 为
  鹿头杖法、目标存活。命中判定
  `ap/2 + random(ap) > 目标parry + 目标dex*10`（ap = staff + 自身con*10）；
  命中造成 `ap + random(ap/2)`（外伤 55%）并扣 180 内力、忙乱 3；
  未命中扣 100 内力、忙乱 4。

  差异（TODO(migrate)）：
  - LPC 首句用 `message_sort`，本引擎统一走 `Broadcast.publish`；
  - 引子在攻击方广播，命中/落空在目标侧结算。
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

  @perform_id "lutou-zhang/tong"
  @move_name "「通天彻地」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_level(stats),
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

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 140 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
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

  defp check_level(stats) do
    if Stats.skill(stats, "lutou-zhang") < 100 do
      {:error, "你鹿头杖法火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "lutou-zhang" do
      :ok
    else
      {:error, "你没有激发鹿头杖法，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    stats = character.meta.stats
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIW "\n$N" HIW "一声暴喝，猛然间腾空而起，手中" + weapon->name()
    #           + HIW "从天而降，气势惊人地" "袭向$n" HIW "。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "\n$N一声暴喝，猛然间腾空而起，手中" <>
          weapon_name <> "从天而降，气势惊人地袭向$n。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        staff: Stats.skill(stats, "staff"),
        con: Stats.query_con(stats),
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("staff") + me->query("con") * 10;
    #      dp = target->query_skill("parry") + target->query("dex") * 10;
    ap = max(Map.get(data, :staff, 0) + Map.get(data, :con, 0) * 10, 1)
    dp = Stats.skill(stats, "parry") + Stats.query_dex(stats) * 10

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2); do_damage(..., damage, 55, ...);
      #      me->start_busy(3); me->add("neili", -180);
      damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 55, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          "$n完全无法看清招中虚实，只听「嘭」地一声，已被$N击中肩膀。\n",
          bindings
        )

      Performs.feedback(attacker, 180, 3)
      put_character(conn, character)
    else
      # LPC: me->start_busy(4); me->add("neili", -100);
      conn =
        Broadcast.publish(
          conn,
          "可是$n奋力招架，左闪右避，好不容易抵挡住了$N的攻击。\n",
          bindings
        )

      Performs.feedback(attacker, 100, 4)
      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "lutou-zhang/tong",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
