defmodule Kantele.Combat.Skills.ZhanshenXinjing do
  @moduledoc """
  战神心经（对照 `kungfu/skill/zhanshen-xinjing.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 天池内功/红花心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 按门派（红花会）分档的成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "zhanshen-xinjing"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["tianchi-neigong", "honghua-xinfa"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候还不够。\n"}

      stats.con < 25 ->
        {:error, "你先天根骨孱弱，无法学习战神心经。\n"}

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
      "powerup" => Kantele.Combat.Skills.ZhanshenXinjing.Powerup,
      "shield" => Kantele.Combat.Skills.ZhanshenXinjing.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.ZhanshenXinjing.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/zhanshen-xinjing/powerup.c`）

  耗 100 内力，临时提升 attack=defense=战神/3，持续 战神 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "zhanshen-xinjing/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够了。"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "zhanshen-xinjing"}, 3},
           defense: {:div, {:skill, "zhanshen-xinjing"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "zhanshen-xinjing"},
      expire_message: "你的战神心经运行完毕，将内力收回丹田。\n",
      message: "$N双目微闭，凝聚战神心经，顿时身后迸出一股罡气将$P全全笼罩。\n"
    }
end

defmodule Kantele.Combat.Skills.ZhanshenXinjing.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/zhanshen-xinjing/shield.c`）

  需战神 ≥50，耗 100 内力，临时提升 armor=战神/2，持续 战神 秒；战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "zhanshen-xinjing/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "zhanshen-xinjing", 50, "你的战神心经修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "zhanshen-xinjing"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "zhanshen-xinjing"},
      expire_message: "你的战神心经运行完毕，将内力收回丹田。\n",
      message: "$N默默凝神聚气，运起战神心经，顿时一股白雾至身后腾起，笼罩全身。\n"
    }
end
