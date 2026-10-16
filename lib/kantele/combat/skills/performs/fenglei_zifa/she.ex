defmodule Kantele.Combat.Skills.Performs.FengleiZifa.She do
  @moduledoc """
  射日诀「she」（对照 `kungfu/skill/fenglei-zifa/she.c`）

  门槛：暗器（handing 抛掷物、余量>=1）、风雷子法>=100、neili>=100、
  目标存活且战斗中。
  攻击方消耗手中暗器 1 枚并发 `perform-incoming`；目标侧掷
  `random(combat_exp + skill³/10)` 对抗 `target combat_exp * 2/3`：命中则
  创伤 `skill/2 + random(skill/2)`；两分支攻击方均扣 80 内力、忙乱 2（回执）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform "fenglei-zifa/she"
  @name "「射日诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, dart} <- handing(character),
         :ok <- level(stats),
         :ok <- neili(character),
         :ok <- target_alive(target) do
      character = consume_dart(character, dart)
      weapon_name = dart.name
      base_unit = Map.get(dart.meta, :base_unit) || ""

      # LPC: msg = HIR "$N" HIR "身形微微一展，单手一晃，只听“飕”的一声，一" +
      #           weapon->query("base_unit") + weapon->name() + HIR "如闪电般" +
      #           "射向$n" HIR "而去。\n" NOR;
      # NOTE: "如闪电般" 与 "射向$n而去。" 为相邻纯字面量，用 Enum.join 保段。
      s1 = "$N身形微微一展，单手一晃，只听“飕”的一声，一"
      middle = Enum.join(["如闪电般", "射向$n而去。\n"], "")
      start_msg = s1 <> base_unit <> (weapon_name || "") <> middle

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          skill: Stats.skill(stats, "fenglei-zifa"),
          combat_exp: stats.combat_exp,
          weapon_name: weapon_name
        }
      })

      conn
      |> put_character(character)
      |> Broadcast.publish(start_msg, n1: character.name, n2: target.name)
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

  defp handing(character) do
    dart = character.inventory |> Enum.find(& &1.handing)

    if dart && Map.get(dart.meta, :skill_type) == "throwing" &&
         (Map.get(dart.meta, :amount) || 1) >= 1 do
      {:ok, dart}
    else
      {:error, "你现在手中并没有拿着暗器，无法施展出#{@name}。\n"}
    end
  end

  defp level(stats) do
    if Stats.skill(stats, "fenglei-zifa") < 100,
      do: {:error, "你的风雷子法不够娴熟，无法施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 100,
      do: {:error, "你内力不足，无法施展#{@name}。\n"},
      else: :ok
  end

  defp target_alive(target) do
    if not dead?(target),
      do: :ok,
      else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp consume_dart(character, dart) do
    amount = (Map.get(dart.meta, :amount) || 1) - 1

    inventory =
      character.inventory
      |> Enum.reject(fn item -> item == dart && amount < 1 end)
      |> Enum.map(fn item ->
        if item == dart, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: item
      end)

    %{character | inventory: inventory}
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :skill, 0), 0)
    weapon_name = Map.get(data, :weapon_name)
    my_exp = Map.get(data, :combat_exp, 0) + div(skill * skill, 10) * skill
    ob_exp = character.meta.stats.combat_exp
    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, max(my_exp, 1)) > div(ob_exp * 2, 3) do
      damage = div(skill, 2) + Engine.rand(rng, max(div(skill, 2), 1))
      vitals = Vitals.wound(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      max_qi = character.meta.vitals.max_qi || character.meta.vitals.qi || 1
      p = div(character.meta.vitals.qi * 100, max(max_qi, 1))

      # LPC: msg += HIR "$n" HIR "闪避不及，顿时被这招打了个血肉模糊"
      #            "的窟窿，整个人疼得几乎都要散架。\n" NOR;
      #      ... msg += "( $n" + eff_status_msg(p) + " )\n";
      hit_msg = "$n闪避不及，顿时被这招打了个血肉模糊的窟窿，整个人疼得几乎都要散架。\n"
      conn = Broadcast.publish(conn, hit_msg, bindings)
      conn = Broadcast.publish(conn, "( $n" <> eff_status_msg(p) <> " )\n", bindings)

      Performs.feedback(attacker, 80, 2)

      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "轻轻一纵，躲闪开了$P" CYN "发出的" +
      #            weapon->name() + CYN "。\n" NOR;
      miss_msg = "可是$p轻轻一纵，躲闪开了$P发出的" <> (weapon_name || "") <> "。\n"
      conn = Broadcast.publish(conn, miss_msg, bindings)

      Performs.feedback(attacker, 80, 2)

      conn
    end
  end

  # LPC: eff_status_msg(p) —— 定义于 /kungfu/skill/eff_msg.h（状态描述按 qi 百分比）。
  # TODO: 该表位于独立头文件，逐条移植待补；当前返回空串以避免引入额外文案。
  defp eff_status_msg(_p), do: ""

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
