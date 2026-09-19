defmodule Kantele.Combat.Skills.Performs.FurongJinzhen.Xian do
  @moduledoc """
  金针现影「xian」（对照 `kungfu/skill/furong-jinzhen/xian.c`）

  门槛：已学会、战斗中且有目标、手持 throwing 暗器（amount>=1）、
  芙蓉金针>=80、force>=120、neili>=150。
  施放即扣所持暗器数量 1（数量归零则脱手消失）；攻击方发
  `perform-incoming`，目标侧掷 `ap/2 + random(ap)` 对抗其
  dodge+parry（ap = force + throwing）：命中造成 `ap/5 + random(ap/5)`
  伤害并创伤，失手则落空；两种情况攻击方均扣 100 内力并 busy 2（回执）。

  差异（TODO(migrate)）：LPC `living(target)` 检查省略（由分派层
  CombatEvent 在目标进程先行拦截死亡目标）；`hit_ob` 的附加
  （jiali+100 的暗器吸血/毒效）未建模，武器名/量词随事件透传。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "furong-jinzhen/xian"
  @name "「金针现影」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, du} <- weapon(character),
         :ok <- level(stats),
         :ok <- force(stats),
         :ok <- neili(character) do
      ap = Stats.effective(stats, "force") + Stats.effective(stats, "throwing")

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          ap: ap,
          level: Stats.skill(stats, "furong-jinzhen"),
          weapon_name: du_name(du),
          unit: du_unit(du)
        }
      })

      character = %{character | inventory: consume_du(character.inventory, du)}

      conn
      |> Broadcast.publish(
        "$N五指陡然箕张，$n但觉眼前金光一闪，数股劲风随即扑面而来！\n",
        n1: character.name,
        n2: target.name
      )
      |> put_character(character)
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
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能在战斗中对对手使用。\n"}
    end
  end

  defp weapon(character) do
    case handing(character) do
      nil -> {:error, "你现在手中并没有拿着暗器。\n"}
      du when is_map(du) -> {:ok, du}
    end
  end

  defp level(stats) do
    if Stats.skill(stats, "furong-jinzhen") < 80,
      do: {:error, "你的芙蓉金针不够娴熟，难以施展#{@name}。\n"},
      else: :ok
  end

  defp force(stats) do
    if Stats.skill(stats, "force") < 120,
      do: {:error, "你的内功火候不够，难以施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 150,
      do: {:error, "你内力不够了。\n"},
      else: :ok
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats

    bindings = [n1: attacker.name, n2: character.name]

    dp = Stats.effective(stats, "dodge") + Stats.effective(stats, "parry")

    if character.meta.combat.busy > 0 do
      conn
    else
      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        damage = div(ap, 5) + Engine.rand(rng, max(div(ap, 5), 1))

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage, 2))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        Performs.feedback(attacker, 100, 2)

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n微微一愣，却已被$N那#{Map.get(data, :unit, "枚")}#{Map.get(data, :weapon_name, "暗器")}正中要穴，入肉半寸之深。\n",
            bindings
          )
        )
        |> put_character(character)
      else
        Performs.feedback(attacker, 100, 2)

        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p早料得$P有此一着，急忙飞身跃起，躲闪开来。\n", bindings)
        )
      end
    end
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type==throwing 的实例
  defp handing(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        Map.get(item.meta, :amount) >= 1
    end)
  end

  defp consume_du(inventory, du) do
    amount = (Map.get(du.meta, :amount) || 1) - 1

    inventory
    |> Enum.map(fn item ->
      if item == du do
        if amount >= 1, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: nil
      else
        item
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp du_name(du), do: Map.get(du.meta, :name) || "暗器"
  defp du_unit(du), do: Map.get(du.meta, :unit) || "枚"

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end