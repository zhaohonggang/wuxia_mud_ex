defmodule Kantele.Combat.Skills.Yujiashu do
  @moduledoc """
  瑜珈术（对照 `kungfu/skill/yujiashu.c`）

  内功载体：`valid_enable("force")` 或 `valid_enable("dodge")`；仅可学不可练。
  `valid_force` 接受 混元一气/少林心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别（必须男性）限制未实现（本模型暂无性别字段）。
  - 源文件带 `dodge_msg` 躲闪文案，`valid_enable` 允许 `"dodge"` 用法，此处仅实现 force 用法。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "yujiashu"

  @impl true
  def valid_enable(usage), do: usage in ["force", "dodge"]

  @impl true
  def valid_force(force), do: force in ["hunyuan-yiqi", "shaolin-xinfa"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的基本内功火候不够，无法学习瑜珈术！\n"}
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
    %{"powerup" => Kantele.Combat.Skills.Yujiashu.Powerup}
  end
end

defmodule Kantele.Combat.Skills.Yujiashu.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/yujiashu/powerup.c`）

  取**基本 force** 等级：需 200 内力，耗 100；临时提升 attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "yujiashu/powerup",
      gates: [
        {:neili_min, 200, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 3},
           defense: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的瑜伽术运行完毕，将内力收回丹田。\n",
      message: "$N厉声一喝，面目似笑非笑，骨骼哗啦哗啦直想，浑身潜力尽数提起！\n"
    }
end
