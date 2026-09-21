defmodule Kantele.Combat.Skills.Performs.HuilongBifa.Cang do
  @moduledoc """
  掌藏龙「cang」（对照 `kungfu/skill/huilong-bifa/cang.c`）

  回龙璧法暗器攻击：消耗 100 内力，扬袖掷出暗器远程攻击，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC 另要求 force>=150 且袖中需持有暗器（handing）；本版以 huilong-bifa>=120 把关；
  - LPC 落空不耗内力，本版统一 100；
  - 命中判定：`rand(level) > parry/2`，忙乱 `level/22+2` 轮；
  - 回龙璧返手与"非回龙璧暗器销毁"效果未建模（TODO(migrate)）。
  - 伤害计算：`damage = level * 2`（简化），LPC 为 `ap/2+rand(ap/2)`。
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

  @perform_id "huilong-bifa/cang"
  @move_name "「掌藏龙」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
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
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, @move_name <> "只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "throwing" do
      :ok
    else
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huilong-bifa")

    if level < 120 do
      {:error, "你的回龙璧法不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不够了。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N一声轻喝，单手一扬，袖底顿时迸出一股气劲，袖中暗器便如蛟龙般射向$n，正是#{@move_name}！\n",
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

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "暗器"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$n只觉劲风袭体，低头间，发现暗器正端端插在自己胸口，顿时惊怒交集，受到#{damage}点伤害！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "可是$p看破了$N的企图，飞身一跃而起，躲避开来。\n",
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