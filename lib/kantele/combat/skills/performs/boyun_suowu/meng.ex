defmodule Kantele.Combat.Skills.Performs.BoyunSuowu.Meng do
  @moduledoc """
  回梦「meng」（对照 `kungfu/skill/boyun-suowu/meng.c`）

  门槛：空手、拨云锁雾>=140、碧云心法>=130、neili>=300、目标存活且战斗中。
  攻击方发 `perform-incoming`；目标侧掷 `ap/2 + random(ap)`（ap = hand）
  对抗其 force：命中则扣目标 qi `ap*3/5`、创伤减半、攻击方忙乱 2 并扣 300 内力；
  失手攻击方忙乱 3（回执）。

  差异（TODO(migrate)）：目标忙乱时整事忽略（与 dagou_bang/chan 同构）；
  `living(target)` 检查省略（由目标侧 `combat/perform-incoming` 死亡检查兜底）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "boyun-suowu/meng"
  @name "「回梦」"

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
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          ap: Stats.skill(stats, "hand")
        }
      })

      conn
      |> Broadcast.publish(
        "$N默念口诀，使出「拨云锁雾」之「回梦」，意欲以内力震晕$n。\n",
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
      do: {:error, "你必须空手才能使用#{@name}！\n"},
      else: :ok
  end

  defp level(stats) do
    if Stats.skill(stats, "boyun-suowu") < 140,
      do: {:error, "你的拨云锁雾不够娴熟，不会使用#{@name}。\n"},
      else: :ok
  end

  defp force(stats) do
    if Stats.skill(stats, "biyun-xinfa") < 130,
      do: {:error, "你的碧云心法不够高，不能用来反震伤敌。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 300,
      do: {:error, "你现在内力太弱，不能使用#{@name}。\n"},
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
      dp = Stats.skill(character.meta.stats, "force")

      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        damage = div(ap * 3, 5)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage, 2))

        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 300, 2)

        conn
        |> Broadcast.publish(Messages.interpolate(damage_message(damage), bindings))
        |> put_character(character)
      else
        Performs.feedback(attacker, 0, 3)
        Broadcast.publish(conn, Messages.interpolate("可是$p看破了$P的企图，并没有上当。\n", bindings))
      end
    end
  end

  defp damage_message(damage) do
    cond do
      damage < 20 -> "结果$n受到$N的内力反震，闷哼一声，看上去很是疲惫。\n"
      damage < 40 -> "结果$n被$N以内力反震，只觉得胸中烦闷，只想好好休息休息。\n"
      damage < 80 -> "结果$n被$N以内力一震，脑中嗡嗡作响，意识开始模糊起来！\n"
      true -> "结果$n被$N的内力一震，眼前一黑，向后便倒，眼看就要不醒人事了！\n"
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end