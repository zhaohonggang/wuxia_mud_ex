defmodule Kantele.Combat.Skills.BeimingShengong do
  @moduledoc """
  北冥神功（对照 `kungfu/skill/beiming-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 逍遥心法/小无相/北冥神功 共存。

  差异（TODO(migrate)）：
  - `suck`（吸功）需空手、等级>=90、目标人类且战斗中、
    内功对抗成功扣目标 max_neili、增自身 max_neili，
    有冷却 temp "sucked"。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "beiming-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["xiaoyao-xinfa", "xiaowuxiang", "beiming-shengong"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.BeimingShengong.Powerup,
      "suck" => Kantele.Combat.Skills.BeimingShengong.Suck
    }
  end

  @impl true
  def perform_list() do
    %{
      "suck" => Kantele.Combat.Skills.BeimingShengong.Suck
    }
  end
end

defmodule Kantele.Combat.Skills.BeimingShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/beiming-shengong/powerup.c`）

  需 100 内力，耗 100；attack=defense=北冥/3，持续 北冥 秒；
  战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "beiming-shengong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够!\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "beiming-shengong"}, 3},
           defense: {:div, {:skill, "beiming-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "beiming-shengong"},
      expire_message: "你的北冥神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起北冥神功，全身真气澎湃，衣衫随之鼓胀。\n"
    }
end

defmodule Kantele.Combat.Skills.BeimingShengong.Suck do
  @moduledoc """
  吸功「suck」（对照 `kungfu/skill/beiming-shengong/suck.c`）

  门槛：北冥>=90、空手、非 no_fight、目标人类存活、
  自身 max_neili < current_neili_limit、目标 max_neili>=100、
  目标 max_neili >= 自身/5、目标非太玄功。
  内力对抗成功：扣目标 max_neili、增自身 max_neili（按差距递减）、
  双方 busy、设 temp "sucked" 冷却。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "beiming-shengong/suck"
  @jie "「北冥神功」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_can_absorb_more(character),
         :ok <- check_target_has_neili(target),
         :ok <- check_target_not_weak(character, target),
         :ok <- check_not_taixuan(target),
         :ok <- check_not_cooldown(character) do
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
        if not enemy.meta.combat.dead do
          {:ok, enemy}
        else
          {:error, "你要吸取谁的丹元？\n"}
        end
      [] ->
        {:error, "你要吸取谁的丹元？\n"}
    end
  end

  defp check_empty_handed(character) do
    if is_nil(Map.get(character.meta.combat.equipped || %{}, :weapon)) do
      :ok
    else
      {:error, "你必须空手才能施用北冥神功吸人丹元！\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "beiming-shengong") >= 90 do
      :ok
    else
      {:error, "你的北冥神功功力不够，不能吸取对方的丹元！\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili >= 20 do
      :ok
    else
      {:error, "你的内力不够，不能使用北冥神功。\n"}
    end
  end

  defp check_can_absorb_more(character) do
    my_max = character.meta.vitals.max_neili
    limit = Map.get(character.meta.stats, :max_neili_limit) || my_max * 2
    if my_max < limit do
      :ok
    else
      {:error, "你的内功水平有限，再吸取也是徒劳。\n"}
    end
  end

  defp check_target_has_neili(target) do
    if target.meta.vitals.max_neili >= 100 do
      :ok
    else
      {:error, "目标丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
    end
  end

  defp check_target_not_weak(character, target) do
    my_max = character.meta.vitals.max_neili
    tg_max = target.meta.vitals.max_neili
    if tg_max >= div(my_max, 5) do
      :ok
    else
      {:error, "目标的内功修为远不如你，你无法从他体内吸取丹元！\n"}
    end
  end

  defp check_not_taixuan(target) do
    if Map.get(target.meta.stats.mapped || %{}, "force") != "taixuan-gong" do
      :ok
    else
      {:error, "目标运行太玄真气将吸功反弹回去。\n"}
    end
  end

  defp check_not_cooldown(character) do
    if not (character.meta.combat.buffs |> Enum.any?(&(&1.key == "sucked"))) do
      :ok
    else
      {:error, "你刚刚吸取过丹元！\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 10}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N全身一振，伸出右手，轻轻握在$n的手臂上。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: Stats.skill(character.meta.stats, "beiming-shengong"),
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

    sp = Stats.skill(attacker.meta.stats, "force")
    dp = Stats.skill(character.meta.stats, "force")

    success = sp + rng.(sp) > dp + rng.(dp)

    if success do
      beiming_lvl = Stats.skill(attacker.meta.stats, "beiming-shengong")
      sucked = 1 + div(beiming_lvl - 90, 10)
      sucked = max(sucked, 1)

      my_max = attacker.meta.vitals.max_neili
      tg_max = character.meta.vitals.max_neili

      sucked =
        cond do
          my_max > tg_max + 100 -> div(sucked, 2)
          my_max > tg_max + 200 -> div(sucked, 2)
          my_max > tg_max + 400 -> div(sucked, 2)
          my_max > tg_max + 800 -> div(sucked, 2)
          my_max > tg_max + 1600 -> div(sucked, 2)
          my_max > tg_max + 3200 -> div(sucked, 2)
          true -> sucked
        end

      if sucked < 1 do
        new_target = %{
          character
          | meta: %{
              character.meta
              | combat: Combat.start_busy(character.meta.combat, 2)
            }
        }

        message = "可是你发现对方内力似乎弱过你太多，一时难以吸收以为己用。\n"

        conn =
          conn
          |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
          |> put_character(new_target)

        Performs.feedback(attacker, %{
          neili_cost: 10,
          busy: 4
        })

        conn
      else
        new_tg_max = max(character.meta.vitals.max_neili - sucked, 0)

        new_target = %{
          character
          | meta: %{
              character.meta
              | vitals: %{character.meta.vitals | max_neili: new_tg_max},
                combat: Combat.start_busy(character.meta.combat, 2)
            }
        }

        message = "你觉得#{character.name}的丹元自手掌源源不绝地流了进来。\n"

        conn =
          conn
          |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
          |> put_character(new_target)

        Performs.feedback(attacker, %{
          neili_cost: 10,
          busy: 4,
          gain_max_neili: sucked
        })

        conn
      end
    else
      new_target = %{
        character
        | meta: %{
            character.meta
            | combat: Combat.start_busy(character.meta.combat, 6)
          }
      }

      message = "可是#{attacker.name}看破了你的企图，机灵地溜了开去。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 10,
        busy: 6
      })

      conn
    end
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