defmodule Kantele.Combat.Skills.XuanmenNeigong do
  @moduledoc """
  玄门内功（对照 `kungfu/skill/xuanmen-neigong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 全真心法/段氏心法/枯荣禅功/素心诀/玉女心经/先天功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xuanmen-neigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "quanzhen-xinfa",
        "duanshi-xinfa",
        "kurong-changong",
        "suxin-jue",
        "yunv-xinjing",
        "xiantian-gong"
      ]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 60 do
      {:error, "你的基本内功火候还不够。\n"}
    else
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
    %{"powerup" => Kantele.Combat.Skills.XuanmenNeigong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.XuanmenNeigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xuanmen-neigong/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=dodge=parry=玄门/4，持续 玄门 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xuanmen-neigong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xuanmen-neigong"}, 4},
           dodge: {:div, {:skill, "xuanmen-neigong"}, 4},
           parry: {:div, {:skill, "xuanmen-neigong"}, 4}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "xuanmen-neigong"},
      expire_message: "你的玄门内功运行完毕，将内力收回丹田。\n",
      message: "$N暗自凝神，运起玄门正宗内功，将全身潜力尽数提起。\n"
    }
end
