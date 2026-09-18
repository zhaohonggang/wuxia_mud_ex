defmodule Kantele.Combat.Skills.BiboShengong do
  @moduledoc """
  碧波神功（对照 `kungfu/skill/bibo-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 落英心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bibo-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "luoying-xinfa"

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "chuixiao-jifa") < 100 do
      {:error, "你没有精通吹箫技法，无法领会碧波神功的奥秘。\n"}
    else
      :ok
    end
  end

  @doc "只能学(learn)或从运功中长熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.BiboShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.BiboShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/bibo-shengong/powerup.c`）

  耗 100 内力，临时提升 attack=defense=碧波/3，持续 碧波 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "bibo-shengong/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "bibo-shengong"}, 3},
           defense: {:div, {:skill, "bibo-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "bibo-shengong"},
      expire_message: "你的碧波神功运行完毕，将内力收回丹田。\n",
      message: "$N仰天一声清啸，全身衣袍顿时如巨涛般向四面扩涨。\n"
    }
end
