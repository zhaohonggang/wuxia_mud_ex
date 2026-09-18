defmodule Kantele.Combat.Skills.XiyangNeigong do
  @moduledoc """
  西洋内功（对照 `kungfu/skill/xiyang-neigong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，故恒真。

  差异（TODO(migrate)）：
  - 源文件 `query_neili_improve` 查询 `xiyang-shengong` 技能（笔误，非自身）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xiyang-neigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 40 do
      {:error, "你的基本内功火候还不够，还不能学习西洋内功。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.XiyangNeigong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.XiyangNeigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xiyang-neigong/powerup.c`）

  取**基本 force** 等级：需 100 内力，耗 90；临时提升 attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xiyang-neigong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 90},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 3},
           defense: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的西洋内功运行完毕，将内力收回丹田。\n",
      message: "$N口中“荷荷”大叫，浑身的肌肉如同充了气一般忽然膨胀起来，威势摄人！\n"
    }
end
