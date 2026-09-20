defmodule Kantele.Combat.Skills.HuagongDafa do
  @moduledoc """
  化功大法（对照 `kungfu/skill/huagong-dafa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 龟息功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili`/毒技门槛未实现。
  - `valid_damage` 被动（化功毒效 + freezing 状态）未接入。
  - `hua`（吸功）实现如下，含目标 max_neili 扣减与自身 busy。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huagong-dafa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "guixi-gong"

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你试着运转了一下内力，登时觉得胸闷难耐！\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的基本内功火候不足，不能学化功大法。\n"}

      Stats.skill(stats, "poison") < 120 ->
        {:error, "你的基本毒技火候不足，不能学化功大法。\n"}

      Stats.skill(stats, "poison") < Stats.skill(stats, id()) ->
        {:error, "你的基本毒技水平有限，不能领会更高深的化功大法。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, id()) ->
        {:error, "你的基本内功水平有限，不能领会更高深的化功大法。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)或练毒的来增加熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

@impl true
  def query_action(_level, _rng \\ &:rand.uniform/1) do
    %{}
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.HuagongDafa.Powerup,
      "hua" => Kantele.Combat.Skills.HuagongDafa.Hua
    }
  end

  @impl true
  def perform_list() do
    %{
      "hua" => Kantele.Combat.Skills.HuagongDafa.Hua
    }
  end
end

defmodule Kantele.Combat.Skills.HuagongDafa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/huagong-dafa/powerup.c`）

  需 100 内力，耗 100；临时提升 attack=dodge=化功/3，持续 化功 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "huagong-dafa/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "huagong-dafa"}, 3},
           dodge: {:div, {:skill, "huagong-dafa"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "huagong-dafa"},
      expire_message: "你的化功大法运行完毕，将内力收回丹田。\n",
      message: "$N脸色一青，充满了煞气，周身泛起萤萤绿光，诡秘异常！\n"
    }
end

defmodule Kantele.Combat.Skills.HuagongDafa.Hua do
  @moduledoc """
  吸功「hua」（对照 `kungfu/skill/huagong-dafa/hua.c`）

  门槛：化功>=100、空手、非 no_fight、目标人类存活、
  自身 neili>=120、目标 neili>=10 且 max_neili>=10、
  目标 max_neili <= 自身 max_neili * 4/3、目标非太玄功。
  内力对抗：sp=force+dodge vs dp=target force+dodge。
  成功：扣目标 max_neili = random(4) + (化功-90)/8，增自身 max_neili 同量、
  双方 busy、扣 neili 100。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "huagong-dafa/hua"
  @jie "「化功大法」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_no_fight(character),
         :ok <- check_not_busy(character),
         :ok <- check_empty_handed(character),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_target_has_neili(target),
         :ok <- check_target_not_stronger(character, target),
         :ok <- check_not_taixuan(target) do
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
          {:error, "你要化谁的内力？\n"}
        end
      [] ->
        {:error, "你要化谁的内力？\n"}
    end
  end

  defp check_no_fight(character) do
    # 引擎未向 perform 暴露房间 no_fight 标志（character 仅 room_id），恒通过；
    # 房间层禁止攻击由 combat_event 兜底（LPC no_fight 差异记 TODO(migrate)）。
    :ok
  end

  defp check_not_busy(character) do
    if character.meta.combat.busy <= 0 do
      :ok
    else
      {:error, "你现在正忙，无法化他人内力。\n"}
    end
  end

  defp check_empty_handed(character) do
    if is_nil(Map.get(character.meta.combat.equipped || %{}, :weapon)) do
      :ok
    else
      {:error, "你必须空手才能施用化功大法！\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "huagong-dafa") >= 100 do
      :ok
    else
      {:error, "你的化功大法功力不够，不能施展！\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili >= 120 do
      :ok
    else
      {:error, "你的内力不够，不能施展化功大法。\n"}
    end
  end

  defp check_target_has_neili(target) do
    if target.meta.vitals.neili >= 10 && target.meta.vitals.max_neili >= 10 do
      :ok
    else
      {:error, target.name <> "已然内力涣散，不必再化了。\n"}
    end
  end

  defp check_target_not_stronger(character, target) do
    my_max = character.meta.vitals.max_neili
    tg_max = target.meta.vitals.max_neili
    if tg_max <= my_max * 4 / 3 do
      :ok
    else
      {:error, target.name <> "的内功修为远胜于你，你无法化他的内力！\n"}
    end
  end

  defp check_not_taixuan(target) do
    if Map.get(target.meta.stats.mapped || %{}, "force") != "taixuan-gong" do
      :ok
    else
      {:error, "目标运行太玄真气将吸功反弹回去。\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N全身骨节爆响，双臂暴长数尺，手掌刷的一抖，粘向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: Stats.skill(character.meta.stats, "huagong-dafa"),
        attacker_force: Stats.skill(character.meta.stats, "force") + Stats.skill(character.meta.stats, "dodge"),
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
    attacker_sp = Map.get(data, :attacker_force, 0)

    sp = attacker_sp
    dp = Stats.skill(character.meta.stats, "force") + Stats.skill(character.meta.stats, "dodge")

    success = div(sp, 2) + rng.(sp) > rng.(dp) || character.meta.combat.dead

    if success do
      # attacker 为瘦引用（ref/1），等级随 perform-incoming data 传递
      lvl = level
      amount = rng.(4) + div(lvl - 90, 8)
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

      message = "你觉得#{character.name}的丹元自手掌源源不绝地流了进来。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 100,
        busy: 2 + rng.(2),
        gain_max_neili: amount
      })

      conn
    else
      new_target = %{
        character
        | meta: %{
            character.meta
            | combat: Combat.start_busy(character.meta.combat, 2 + rng.(3))
          }
      }

      message = "可是#{attacker.name}看破了你的企图，内力猛地一震，借势溜了开去。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 100,
        busy: 2 + rng.(3)
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