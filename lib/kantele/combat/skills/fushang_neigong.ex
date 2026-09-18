defmodule Kantele.Combat.Skills.FushangNeigong do
  @moduledoc """
  扶桑内功（对照 `kungfu/skill/fushang-neigong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，继承 `FORCE` 缺省（不限共存），故此处恒真。

  差异（TODO(migrate)）：
  - `query_neili_improve` 误用 `fushang-shengong` 成长公式，未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fushang-neigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 50 do
      {:error, "你的基本内功火候还不够，还不能学习扶桑内功。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.FushangNeigong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.FushangNeigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/fushang-neigong/powerup.c`）

  取**基本 force** 等级：耗 90 内力，临时提升 attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "fushang-neigong/powerup",
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
      expire_message: "你的扶桑内功运行完毕，将内力收回丹田。\n",
      message: "$N大喝一声，运起扶桑内功，全身骨节发出一阵爆豆般的声响！\n"
    }
end
