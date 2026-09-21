defmodule Kantele.Combat.Skills.Performs.JimieZhua.Wuwo do
  @moduledoc """
  众生无我「wuwo」（对照 `kungfu/skill/jimie-zhua/wuwo.c`）

  寂灭爪单体攻击：消耗 200 内力，双爪分路抓出，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC 仅 `level:jimie-zhua>=80`；本版加 `mapped` 与 `neili` 门槛；
  - LPC 命中/落空分别消耗 200/20，本版统一 200；
  - 命中判定：LPC 以 force+claw 对 parry+dodge，本版以 `rand(level) > parry/2` 代理；
  - 忙乱：命中 2 轮、落空 3 轮，本版 `level/22+2` 轮。
  - 伤害计算：`damage = level * 2`（简化），LPC 为 `ap/3+rand(ap/4)`。
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

  @perform_id "jimie-zhua/wuwo"
  @move_name "「众生无我」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_mapped(stats),
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
      {:error, @move_name <> "只能在战斗中对对手使用。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, @move_name <> "只能在战斗中对对手使用。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "jimie-zhua")

    if level < 80 do
      {:error, "你的寂灭爪等级不够，不会使用#{@move_name}！\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "claw") == "jimie-zhua" do
      :ok
    else
      {:error, "你没有激发寂灭爪，无法使用#{@move_name}！\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N猛地扑上前来，双爪分两路向$n抓出，平淡的一击，却显示出扎实的基本功！\n",
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

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "爪"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "慌乱中，$p不及招架$N这看似简单的一抓，结果被抓了个正中，喀的一声，$p身上多了一条伤痕，受到#{damage}点伤害！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "可是$p见来势凶猛，连忙招架，顺势跃开，没有被$N得手。\n",
            bindings
          )
        else
          Messages.interpolate("但是$p双手戳点刺拍，将$N的来招一一架开。\n", bindings)
        end

      Broadcast.publish(conn, text)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end