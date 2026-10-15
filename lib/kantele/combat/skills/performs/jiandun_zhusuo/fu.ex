defmodule Kantele.Combat.Skills.Performs.JiandunZhusuo.Fu do
  @moduledoc """
  缚字诀「fu」（对照 `kungfu/skill/jiandun-zhusuo/fu.c`）

  剑盾珠索缠绕技：需持鞭、剑盾珠索>=50、真气>=50、激发 whip 为剑盾珠索、
  目标未处于忙乱。命中（`random(剑盾珠索) > 目标 parry/2`）则目标忙乱
  `剑盾珠索/20 + 1` 轮，攻击方忙乱 1 轮。

  差异（TODO(migrate)）：
  - `target->is_busy()` 取引用快照 meta 的 combat.busy（缺 meta 时按未忙处理）；
  - 命中/落空在目标侧结算。
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

  @perform_id "jiandun-zhusuo/fu"
  @move_name "「缚字诀」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_target_busy(target),
         {:ok, weapon} <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, level, weapon)
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

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp busy?(%{meta: %{combat: %{busy: busy}}}), do: busy > 0
  defp busy?(_), do: false

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      {:ok, weapon}
    else
      {:error, "你的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "jiandun-zhusuo")

    if level < 50 do
      {:error, "你的剑盾珠索级别不够，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "jiandun-zhusuo" do
      :ok
    else
      {:error, "你没有激发剑盾珠索，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, level, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    conn =
      Broadcast.publish(
        conn,
        "$N右手一扬，手中" <> weapon_name <> "顿时回旋飞舞而至，迂回盘绕向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        weapon_name: weapon_name,
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
    weapon_name = Map.get(data, :weapon_name, "")
    level = Map.get(data, :level, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: me->start_busy(1);
    Performs.feedback(attacker, 0, 1)

    # LPC: random(me->query_skill("jiandun-zhusuo", 1)) > target->query_skill("parry", 1) / 2
    if Engine.rand(rng, max(level, 1)) > div(Stats.skill(stats, "parry"), 2) do
      # LPC: target->start_busy(me->query_skill("jiandun-zhusuo") / 20 + 1);
      combat = Combat.start_busy(character.meta.combat, div(level, 20) + 1)

      conn =
        Broadcast.publish(
          conn,
          "$n只觉全身一紧，已被" <> weapon_name <> "牢牢缚住，动弹不得！\n",
          bindings
        )

      put_character(conn, put_combat(character, combat))
    else
      Broadcast.publish(conn, "可是$p看破了$P的企图，斜跳躲闪开来。\n", bindings)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "jiandun-zhusuo/fu",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
