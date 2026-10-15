defmodule Kantele.Combat.Skills.Performs.HuashanJian.Long do
  @moduledoc """
  天外飞龙「long」（对照 `kungfu/skill/huashan-jian/long.c`）

  华山剑法掷剑绝招：需持剑、华山剑法>=150、force>=150、真气>=220、
  激发 sword 为华山剑法。攻击方算 `ap`（sword 技能）并下发
  `combat/perform-incoming`，由目标侧 `resolve_incoming` 以 dodge 判定命中。

  命中条件：`ap > dp / 2 * 3 && ap / 2 + random(ap) > dp`；
  命中伤害 `max_qi/4 + ap + random(damage/4)`（外伤 55%），扣 200 内力、忙乱 3；
  落空扣 120 内力、忙乱 3。

  差异（TODO(migrate)）：
  - LPC 命中后武器脱手落于此地（`weapon->move(environment(me))`），本版不加此效果。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "huashan-jian/long"
  @move_name "「天外飞龙」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, level)
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
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对！\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huashan-jian")

    if level < 150 do
      {:error, "你华山剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你内功火候不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 220 do
      {:error, "你现在真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huashan-jian" do
      :ok
    else
      {:error, "你没有激发华山剑法，无法施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, _level) do
    stats = character.meta.stats

    conn =
      Broadcast.publish(
        conn,
        "$N心念电闪，一提内力，勒手仗剑，运劲于臂，呼的一声向$n掷了出去，\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword")
      }
    })

    assign(conn, :prompt, false)
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
    vitals = character.meta.vitals
    bindings = [n1: attacker.name, n2: character.name]

    ap = Map.get(data, :ap, 0)
    dp = Stats.skill(stats, "dodge")

    # LPC: if (ap > dp / 2 * 3 && ap / 2 + random(ap) > dp)
    if ap > div(dp, 2) * 3 and div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      damage = div(vitals.max_qi, 4) + ap
      damage = damage + Engine.rand(rng, max(div(damage, 4), 1))

      vitals =
        vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 55, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(3); me->add("neili", -200);
      Performs.feedback(attacker, 200, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n疾忙跃起，但剑如电闪，只觉一阵剧痛，剑刃拦腰而过，鲜血飞溅，皮肉卷起！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3); me->add("neili", -120);
      Performs.feedback(attacker, 120, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate("然而$n轻轻一笑，侧身伸指，正弹在$N的剑脊上，剑斜飞落地。\n", bindings)
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "huashan-jian/long",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
