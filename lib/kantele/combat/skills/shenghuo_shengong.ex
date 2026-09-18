defmodule Kantele.Combat.Skills.ShenghuoShengong do
  @moduledoc """
  圣火神功（对照 `kungfu/skill/shenghuo-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 圣火心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  - `hit_ob` 被动（圣火令法连击）属攻击侧被动，未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "shenghuo-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "shenghuo-xinfa"

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 32 -> {:error, "你先天悟性不够，无法领悟圣火神功。\n"}
      Stats.skill(stats, "force") < 180 -> {:error, "你的基本内功火候还不够，还不能学习圣火神功。\n"}
      true -> :ok
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
      "powerup" => Kantele.Combat.Skills.ShenghuoShengong.Powerup,
      "shield" => Kantele.Combat.Skills.ShenghuoShengong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.ShenghuoShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/shenghuo-shengong/powerup.c`）

  需 150 内力，耗 150；临时提升 attack=dodge=parry=圣火/3，持续 圣火 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "shenghuo-shengong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 150},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "shenghuo-shengong"}, 3},
           dodge: {:div, {:skill, "shenghuo-shengong"}, 3},
           parry: {:div, {:skill, "shenghuo-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "shenghuo-shengong"},
      expire_message: "你的圣火神功运行完毕，长长地吐了口气，将内力收回丹田。\n",
      message: "$N默运圣火神功，脸色先由黄翻紫，紧接着由紫翻蓝，再由蓝翻红，最后又恢复为黄色，甚为诡异。\n"
    }
end

defmodule Kantele.Combat.Skills.ShenghuoShengong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/shenghuo-shengong/shield.c`）

  需圣火 ≥40，耗 100 内力，临时提升 armor=圣火/2，持续 圣火 秒；战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "shenghuo-shengong/shield",
      gates: [
        {:neili_min, 100, "你的真气不够。\n"},
        {:skill_min, "shenghuo-shengong", 40, "你的圣火神功等级不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "shenghuo-shengong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "shenghuo-shengong"},
      expire_message: "你的圣火神功运行完毕，将内力收回丹田。\n",
      message: "$N默念圣火神功口诀，一股真气流至奇经八脉，护住全身。\n"
    }
end
