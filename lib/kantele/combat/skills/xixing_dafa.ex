defmodule Kantele.Combat.Skills.XixingDafa do
  @moduledoc """
  吸星大法（对照 `kungfu/skill/xixing-dafa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili`/`can_learn` 前置未实现。
  - `valid_damage` 被动（吸化对方内力）未接入。
  - `suck`（吸功）实现如下，含目标 max_neili 扣减与自身 max_neili 增加。
  - `sangong`（散功）实现如下，扣除自身 max_neili。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xixing-dafa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你试着按照法门运转了一下内息，忽然觉得心火如焚，丹田却是一阵冰凉！\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功修为不足，难以修炼吸星大法。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)或从运用(exert)中增加熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.XixingDafa.Powerup,
      "suck" => Kantele.Combat.Skills.XixingDafa.Suck,
      "sangong" => Kantele.Combat.Skills.XixingDafa.Sangong
    }
  end

  @impl true
  def perform_list() do
    %{
      "suck" => Kantele.Combat.Skills.XixingDafa.Suck
    }
  end
end

defmodule Kantele.Combat.Skills.XixingDafa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xixing-dafa/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=吸星/3，持续 吸星 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xixing-dafa/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xixing-dafa"}, 3},
           defense: {:div, {:skill, "xixing-dafa"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "xixing-dafa"},
      expire_message: "你的吸星大法运行完毕，将内力收回丹田。\n",
      message: "$N深深呼入一口气，缓缓吐出，顿时全身真气蒸腾，被罡劲所笼罩。\n"
    }
end

defmodule Kantele.Combat.Skills.XixingDafa.Suck do
  @moduledoc """
  吸功「suck」（对照 `kungfu/skill/xixing-dafa/suck.c`）

  门槛：吸星>=200、非 no_fight、目标人类存活且战斗中、
  自身 max_neili < current_neili_limit、目标 max_neili>=100、
  目标 max_neili >= 自身/5、目标非太玄功。
  内力对抗：sp=force vs dp=target force。
  成功：扣目标 max_neili = 1 + (吸星-120)/10，增自身 max_neili 同量、
  增 exception/xixing-count，双方 busy、扣 neili 10。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "xixing-dafa/suck"
  @jie "「吸星大法」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_no_fight(character),
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
          {:error, "你只能吸取战斗中的对手的丹元！\n"}
        end
      [] ->
        {:error, "你只能吸取战斗中的对手的丹元！\n"}
    end
  end

  defp check_no_fight(character) do
    # 引擎未向 perform 暴露房间 no_fight 标志（character 仅 room_id），恒通过；
    # 房间层禁止攻击由 combat_event 兜底（LPC no_fight 差异记 TODO(migrate)）。
    :ok
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "xixing-dafa") >= 200 do
      :ok
    else
      {:error, "你的吸星大法尚未大成，还不能吸取对方的丹元收为己用！\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili >= 100 do
      :ok
    else
      {:error, "你的内力不够，不能使用吸星大法。\n"}
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
      {:error, target.name <> "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
    end
  end

  defp check_target_not_weak(character, target) do
    my_max = character.meta.vitals.max_neili
    tg_max = target.meta.vitals.max_neili
    if tg_max >= div(my_max, 5) do
      :ok
    else
      {:error, target.name <> "的内功修为远不如你，你无法从他体内吸取丹元！\n"}
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

    message =
      if Map.get(character.meta.combat.equipped || %{}, :weapon) do
        "$N把手中的#{Map.get(character.meta.combat.equipped, :weapon).name}一扬，慢慢的逼向#{target.name}，#{target.name}连忙架住。\n"
      else
        "$N探出右手，平平的拍在#{target.name}的胸前，似乎没有半点力道。\n"
      end

    conn =
      Broadcast.publish(conn, message, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: Stats.skill(character.meta.stats, "xixing-dafa"),
        attacker_force: Stats.skill(character.meta.stats, "force"),
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
    attacker_force = Map.get(data, :attacker_force, 0)

    sp = attacker_force
    dp = Stats.skill(character.meta.stats, "force")

    success = sp + rng.(sp) > dp + rng.(dp) || character.meta.combat.dead

    if success do
      # attacker 为瘦引用（ref/1），等级随 perform-incoming data 传递
      lvl = level
      amount = 1 + div(lvl - 120, 10)
      amount = max(amount, 1)

      new_tg_max = max(character.meta.vitals.max_neili - amount, 0)

      new_target = %{
        character
        | meta: %{
            character.meta
            | vitals: %{character.meta.vitals | max_neili: new_tg_max},
              combat: Combat.start_busy(character.meta.combat, 2)
          }
      }

      message = "你觉得#{attacker.name}的丹元自手掌源源不绝地流了进来。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 10,
        busy: 4 + rng.(4),
        gain_max_neili: amount
      })

      conn
    else
      new_target = %{
        character
        | meta: %{
            character.meta
            | combat: Combat.start_busy(character.meta.combat, 7)
          }
      }

      message = "可是#{attacker.name}看破了你的企图，运用内力震开了你，随即躲了开去。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 10,
        busy: 7
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

defmodule Kantele.Combat.Skills.XixingDafa.Sangong do
  @moduledoc """
  散功「sangong」（对照 `kungfu/skill/xixing-dafa/sangong.c`）

  门槛：max_neili >= 1。
  扣 max_neili 1，busy 1。
  """

  use Kantele.Combat.Performs.Simple,
    spec: :local

  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  @impl true
  def id(), do: "xixing-dafa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"sangong" => __MODULE__}
  end

  def spec() do
    %Spec{
      id: "xixing-dafa/sangong",
      kind: :exert,
      gates: [
        {:max_neili_min, 1, "你已经将内力散尽，没什么必要再散功了。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_sangong/1}
      ],
      busy: 1,
      message: "你默默的按照吸星大法的诀窍将内力散入奇经八脉。\n"
    }
  end

  defp effect_sangong(state) do
    char = state.character
    new_vitals = %{char.meta.vitals | max_neili: max(char.meta.vitals.max_neili - 1, 0)}
    new_char = %{char | meta: %{char.meta | vitals: new_vitals}}
    state
    |> Map.put(:character, new_char)
    |> Map.put(:message, "你默默的按照吸星大法的诀窍将内力散入奇经八脉。\n")
  end
end