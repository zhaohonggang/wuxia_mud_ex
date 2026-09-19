defmodule Kantele.Combat.Skills.Performs.BoyunSuowu.Dian do
  @moduledoc """
  云雾暗点「dian」（对照 `kungfu/skill/boyun-suowu/dian.c`）

  门槛：空手、拨云锁雾>=100、碧云心法>=100、neili>=800、目标存活且战斗中。
  攻击方发 `perform-incoming`；目标侧掷 `ap/2 + random(ap)`
  （ap = hand + dex*10）对抗 `dodge + dex*10`：命中则目标忙乱 `ap/100+2`；
  两分支攻击方均扣 500 内力（回执）。

  差异（TODO(migrate)）：LPC 在 `target->is_busy()` 时不追加忙乱、仍扣内力，
  本版目标忙乱时整事忽略（与 dagou_bang/chan 同构）；`living(target)` 检查省略
  （敌人列表只存引用快照，由目标侧 `combat/perform-incoming` 死亡检查兜底）。
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
  alias Kantele.Combat.Performs

  @perform "boyun-suowu/dian"
  @name "「云雾暗点」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- empty_handed(combat),
         :ok <- level(stats),
         :ok <- force(stats),
         :ok <- neili(character) do
      ap = Stats.skill(stats, "hand") + stats.dex * 10

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          ap: ap,
          level: Stats.skill(stats, "boyun-suowu")
        }
      })

      conn
      |> Broadcast.publish(
        "$N手腕一翻，信手一个拈花诀，内力暗吐，“嗤”的一声，破空而去！\n",
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
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能对战斗中的对手使用。\n"}
    end
  end

  defp empty_handed(combat) do
    if Combat.weapon(combat),
      do: {:error, "你只能空手使用#{@name}。\n"},
      else: :ok
  end

  defp level(stats) do
    if Stats.skill(stats, "boyun-suowu") < 100,
      do: {:error, "你的「拨云锁雾」不够娴熟，不能使用#{@name}。\n"},
      else: :ok
  end

  defp force(stats) do
    if Stats.skill(stats, "biyun-xinfa") < 100,
      do: {:error, "你的碧云心法不够熟练！\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 800,
      do: {:error, "你的内力不够。\n"},
      else: :ok
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.busy > 0 do
      conn
    else
      dp = Stats.skill(character.meta.stats, "dodge") + character.meta.stats.dex * 10

      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        combat = Combat.start_busy(character.meta.combat, div(ap, 100) + 2)
        character = %{character | meta: %{character.meta | combat: combat}}
        Performs.feedback(attacker, 500, 0)

        conn
        |> Broadcast.publish(Messages.interpolate("$n全身顿觉一麻，似乎不能动弹。\n", bindings))
        |> put_character(character)
      else
        Performs.feedback(attacker, 500, 0)
        Broadcast.publish(conn, Messages.interpolate("只见$n侧身一让，一阵风声，破空而过！\n", bindings))
      end
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end