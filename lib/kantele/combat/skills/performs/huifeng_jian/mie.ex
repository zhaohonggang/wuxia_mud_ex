defmodule Kantele.Combat.Skills.Performs.HuifengJian.Mie do
  @moduledoc """
  灭剑「mie」（对照 `kungfu/skill/huifeng-jian/mie.c`）

  回风拂柳剑法单体攻击：消耗 150 内力，漫天剑影化为一剑直刺，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC 另要求 force>=180；本版仅以 huifeng-jian>=120 与 mapped 把关；
  - LPC 命中判定为 force/exp 对 force/exp，本版以 `rand(level) > parry/2` 代理；
  - 命中/落空分别消耗 150/60，本版统一 150；
  - 忙乱：命中 2 轮、落空 3 轮，本版 `level/22+2` 轮。
  - 伤害计算：`damage = level * 2`（简化），LPC 为 `huifeng-jian+rand(huifeng-jian)`。
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

  @perform_id "huifeng-jian/mie"
  @move_name "「灭剑」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
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
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, @move_name <> "只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huifeng-jian")

    if level < 120 do
      {:error, "你的回风拂柳剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huifeng-jian" do
      :ok
    else
      {:error, "你没有激发回风拂柳剑法，无法施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N手中长剑剑芒跃动，剑光暴长，幻出死亡的色彩，施展#{@move_name}，" <>
          "漫天剑影化为一剑直刺$n前胸，快捷无伦！\n",
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

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "剑"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$p全然无法躲避，长剑端端正正扎进胸口，鲜血登时飞溅而出，受到#{damage}点伤害！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "可是$p轻轻一笑，侧身右转，伸出两指，正弹在$N的剑上，有惊无险。\n",
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