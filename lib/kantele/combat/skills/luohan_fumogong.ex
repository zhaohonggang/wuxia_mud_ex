defmodule Kantele.Combat.Skills.LuohanFumogong do
  @moduledoc """
  罗汉伏魔神功（对照 `kungfu/skill/luohan-fumogong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，故恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格（心狠手辣/阴险奸诈）判定与 `max_neili>=1000`
    检查（`valid_learn/1` 仅有 stats，无 vitals）未实现。
  - 性别判定误用 `query("luohan-fumogong",1)`（永不触发），未实装。
  - `powerup` 的施展门槛（少林派或饮过玄冰碧火酒）与文案分档依赖
    family/item，未建模：本实现不校验门派、文案取非少林分支。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "luohan-fumogong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 30 -> {:error, "你先天悟性不足，难以领会罗汉伏魔神功。\n"}
      stats.con < 30 -> {:error, "你先天根骨孱弱，无法修炼罗汉伏魔神功。\n"}
      Stats.skill(stats, "force") < 100 -> {:error, "你的基本内功火候不足，不能学罗汉伏魔神功。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.LuohanFumogong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.LuohanFumogong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/luohan-fumogong/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=罗汉/3，持续 罗汉 秒；
  战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "luohan-fumogong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "luohan-fumogong"}, 3},
           defense: {:div, {:skill, "luohan-fumogong"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "luohan-fumogong"},
      expire_message: "你的罗汉伏魔神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起罗汉伏魔神功，全身肌肤竟交替呈现出靛青与血红两色。\n"
    }
end
