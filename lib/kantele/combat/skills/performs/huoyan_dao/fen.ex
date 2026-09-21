defmodule Kantele.Combat.Skills.Performs.HuoyanDao.Fen do
  @moduledoc """
  焚身「fen」（对照 `kungfu/skill/huoyan-dao/fen.c`）

  火焰刀绝招：消耗 300 内力，聚气于掌发出无形刀气，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC 另要求 force>=120（本版仅以 huoyan-dao>=120 把关）；
    LPC 与清单均未检查武器与 mapped，本版保持一致；
  - LPC 命中/落空分别消耗 300/150，本版统一 300；
  - LPC 命中判定为 force+skill/3 对 force（dp 下限 1），本版以
    `rand(level) > parry/2` 代理；
  - 忙乱：命中 2 轮、落空 3 轮，本版 `level/22+2` 轮。
  - 伤害计算：`damage = level * 2`（简化），LPC 为 `150+skill/4+rand(skill)`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "huoyan-dao/fen"
  @move_name "「焚身」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character) do
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
      {:error, "你还不会运用#{@move_name}这一绝技。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, @move_name <> "只能对战斗中的对手使用。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huoyan-dao")

    if level < 120 do
      {:error, "你的火焰刀等级不够，还不能使出#{@move_name}！\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的内力不够，无法运功！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N聚气于掌，使出一招#{@move_name}，无形刀气向$n的胸口击去。\n",
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
        ap: level * 2,
        dp: 0
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "掌"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$p强运内力试图抵抗，然而无法掌握$N内力的变化，被无形刀气重创在胸口，受到#{damage}点伤害！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate("却见$p不慌不忙，轻轻一闪，躲过了$N的必杀一击！\n", bindings)
        else
          Messages.interpolate("却见$p不慌不忙，轻轻一闪，躲过了$N的必杀一击！\n", bindings)
        end

      Broadcast.publish(conn, text)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end