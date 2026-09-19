defmodule Kantele.Combat.Skills.BingxinJue do
  @moduledoc """
  冰心诀（对照 `kungfu/skill/bingxin-jue.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真（未声明）。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别判定误用 `query("bingxin-jue",1)`（永不触发），未实装。
  - `freeze`（寒气）实现如下，需 skill>=150、neili>=1000、目标存活、在战斗中。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bingxin-jue"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你的先天根骨孱弱，无法修炼冰心诀。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候不足，不能学冰心诀。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1) do
    %{}
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.BingxinJue.Powerup,
      "freeze" => Kantele.Combat.Skills.BingxinJue.Freeze
    }
  end

  @impl true
  def perform_list() do
    %{
      "freeze" => Kantele.Combat.Skills.BingxinJue.Freeze
    }
  end
end

defmodule Kantele.Combat.Skills.BingxinJue.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/bingxin-jue/powerup.c`）

  需 300 内力，耗 100；临时提升 attack=defense=冰心/3，持续 冰心 秒；
  战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "bingxin-jue/powerup",
      gates: [
        {:neili_min, 300, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "bingxin-jue"}, 3},
           defense: {:div, {:skill, "bingxin-jue"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "bingxin-jue"},
      expire_message: "你的冰心诀运行完毕，将内力收回丹田。\n",
      message: "$N双掌一合，冰心诀真气激荡，周身白雾缭绕，寒气逼人。\n"
    }
end

defmodule Kantele.Combat.Skills.BingxinJue.Freeze do
  @moduledoc """
  寒气「freeze」（对照 `kungfu/skill/bingxin-jue/freeze.c`）

  门槛：冰心>=150、neili>=1000、目标存活、在战斗中。
  ap=force, dp=force 对抗；成功：damage=force/3+random(force/3)，扣目标 qi/劲 qi、
  扣目标 neili = damage（若目标 neili > damage），busy 1。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "bingxin-jue/freeze"
  @jie "「冰心诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target)
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
      [enemy | _] ->
        if enemy.meta.vitals.alive? do
          {:ok, enemy}
        else
          {:error, "你只能用寒气攻击战斗中的对手。\n"}
        end
      [] ->
        {:error, "你只能用寒气攻击战斗中的对手。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "bingxin-jue") >= 150 do
      :ok
    else
      {:error, "你的冰心决火候不够，无法运用寒气。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili >= 1000 do
      :ok
    else
      {:error, "你的内力不够!\n"}
    end
  end

  defp check_target_alive(target) do
    if target.meta.vitals.alive? do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    conn =
      Broadcast.publish(
        conn,
        "$N默运冰心决，一股寒气迎面扑向$n，四周登时雪花飘飘。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: Stats.skill(character.meta.stats, "bingxin-jue"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    ap = Stats.skill(attacker.meta.stats, "force")
    dp = Stats.skill(character.meta.stats, "force")

    success = div(ap, 2) + rng.(ap) > rng.(dp)

    if success do
      damage = div(ap, 3) + rng.(div(ap, 3))

      new_t_q = max(character.meta.vitals.qi - damage, 0)
      new_t_eff_q = max(character.meta.vitals.max_qi - damage, 0)

      new_t_neili =
        if character.meta.vitals.neili > damage,
          do: character.meta.vitals.neili - damage,
          else: 0

      new_target = %{
        character
        | meta: %{
            character.meta
            | vitals: %{
                character.meta.vitals
                | qi: new_t_q,
                  max_qi: new_t_eff_q,
                  neili: new_t_neili
              },
              combat: Combat.start_busy(character.meta.combat, 1)
          }
      }

      message = "$N默运冰心决，一股寒气迎面扑向$n，四周登时雪花飘飘。\n" <>
                "你觉得#{attacker.name}的全身功力如融雪般消失得无影无踪！\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 0,
        busy: 2
      })
    else
      message = "$N默运冰心决，一股寒气迎面扑向$n，四周登时雪花飘飘。\n" <>
                "你感到一阵寒意自心底泛起，连忙运动抵抗，堪勘无事。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(character)

      Performs.feedback(attacker, %{
        neili_cost: 0,
        busy: 2
      })
    end

    conn
  end

  defp ref(character) do
    %{
      id: character.id,
      pid: character.pid,
      name: character.name,
      room_id: character.room_id,
      meta: character.meta
    }
  end
end