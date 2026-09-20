defmodule Kantele.Combat.Skills.Performs.DamoJian.Qingxin do
  @moduledoc """
  清心剑「qingxin」（对照 `kungfu/skill/damo-jian/qingxin.c`）

  门槛：达摩剑>=200、force ap（sword+force）、neili>=300、锻造 sword 为达摩剑、
  目标存活且战斗中、目标未中清心剑。

  攻击方扣 200 内力并忙乱 1 回合（同步执行，同 LPC）；随后发 `perform-incoming`。
  目标侧 `resolve_incoming/4`：目标未运「powerup」则守方安然无恙；
  否则判 `ap/2 + random(ap)` vs 目标 `force*2`；命中则抽走目标 temp 的
  attack/defense 加成并挂 `damo-qingxin` buff，`ap/20` 秒后由
  `combat/buff-expire` 加回（文案「你觉得力气恢复了一些」）。

  差异（TODO(migrate)）：
  - LPC 门槛在攻击侧查目标 `damo_qingxin`，本引擎敌列表只存引用快照，
    叠防改由目标侧幂等处理（重复命中直接再次覆盖）；
  - LPC `remove_effect` 的 `tell_object`（私有）经引擎 `combat/buff-expire`
    广播（可接受偏差，与既有流派 buff 一致）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages

  @perform "damo-jian/qingxin"
  @name "「清心剑」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         {:ok, _level} <- level(stats),
         :ok <- mapped(stats, weapon),
         :ok <- neili(character) do
      vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 200, 0)}
      ap = Stats.skill(stats, "sword") + Stats.skill(stats, "force")
      combat = Combat.start_busy(combat, 1)

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, ap: ap}
      })

      conn
      |> put_character(character)
      |> Broadcast.publish(
        "$N将手中的" <> Map.get(weapon, :name) <> "轻轻一抖，一股剑气悄然而出，分作数路攻向$n！\n",
        n1: character.name,
        n2: target.name
      )
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform),
      do: :ok,
      else: {:error, "你不会使用#{@name}。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: type} = weapon when type == "sword" -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对。\n"}
    end
  end

  defp level(stats) do
    level = Stats.skill(stats, "damo-jian")

    if level < 200,
      do: {:error, "你的达摩剑法不够娴熟，不会使用#{@name}。\n"},
      else: {:ok, level}
  end

  defp mapped(stats, weapon) do
    if Stats.mapped(stats, weapon.skill_type) == "damo-jian",
      do: :ok,
      else: {:error, "你没有激发达摩剑法，无法使用#{@name}。\n"}
  end

  defp neili(character) do
    if character.meta.vitals.neili < 300,
      do: {:error, "你现在真气不够，无法使用#{@name}。\n"},
      else: :ok
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    dp = Stats.skill(character.meta.stats, "force") * 2

    result =
      if not Combat.buff_active?(character.meta.combat, "powerup") do
        {character.meta.combat,
         "可是$p看来似乎并没有运用真气提升战力，$P这一招没有起到任何作用。\n"}
      else
        if div(ap, 2) + Engine.rand(rng, ap) > dp do
          ainc = Map.get(character.meta.combat.temp, :attack, 0)
          dinc = Map.get(character.meta.combat.temp, :defense, 0)

          combat =
            character.meta.combat
            |> Combat.apply_temp(%{attack: -ainc, defense: -dinc})
            |> Combat.add_buff(%Combat.Buff{
              key: "damo-qingxin",
              applies: %{attack: ainc, defense: dinc}
            })

          Process.send_after(
            self(),
            %Event{
              from_pid: self(),
              topic: "combat/buff-expire",
              data: %{
                key: "damo-qingxin",
                applies: %{attack: ainc, defense: dinc},
                message: "你觉得力气恢复了一些。\n"
              }
            },
            max(div(ap, 20), 1) * 1000
          )

          {combat, "结果$p觉得浑身一麻，手足软软的竟然使不出一点力道！\n"}
        else
          {character.meta.combat, "可是$p内力深厚，使得$P这一招没有起到任何作用。\n"}
        end
      end

    {combat, text} = result
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(Messages.interpolate(text, bindings))
    |> put_character(character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end