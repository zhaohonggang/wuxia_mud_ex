defmodule Kantele.Combat.Skills.TaijiShengong do
  @moduledoc """
  太极神功（对照 `kungfu/skill/taiji-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 混元一气功/易筋经/武当心法/临济庄/峨眉心法/少林心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "taiji-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "hunyuan-yiqi",
        "yijinjing",
        "wudang-xinfa",
        "linji-zhuang",
        "emei-xinfa",
        "shaolin-xinfa"
      ]

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")
    taoism = Stats.skill(stats, "taoism")
    level = Stats.skill(stats, id())

    cond do
      force < 100 ->
        {:error, "你的基本内功火候还不够。\n"}

      taoism < 100 ->
        {:error, "你对道家心法领悟的太浅，无法理解太极神功。\n"}

      taoism < 320 and taoism < level ->
        {:error, "你对道学心法的理解不够，难以锻炼更深厚的太极神功。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.TaijiShengong.Powerup,
      "shield" => Kantele.Combat.Skills.TaijiShengong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.TaijiShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/taiji-shengong/powerup.c`）

  需 150 内力方可发动，实际耗 100；临时提升 attack=defense=太极/3，
  持续 太极 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "taiji-shengong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "taiji-shengong"}, 3},
           defense: {:div, {:skill, "taiji-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "taiji-shengong"},
      expire_message: "你的太极神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起太极神功，全身灌满真气，衣裳无风自舞，气势迫人。\n"
    }
end

defmodule Kantele.Combat.Skills.TaijiShengong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/taiji-shengong/shield.c`）

  需太极 ≥50，耗 100 内力，临时提升 armor=太极/2，持续 太极 秒；
  战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "taiji-shengong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "taiji-shengong", 50, "你的太极神功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "taiji-shengong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "taiji-shengong"},
      expire_message: "你的太极神功运行完毕，将内力收回丹田。\n",
      message: "$N深深吸了一口气，缓缓吐出，一股白烟冉冉透体而出，盘旋笼罩了全身。\n"
    }
end
