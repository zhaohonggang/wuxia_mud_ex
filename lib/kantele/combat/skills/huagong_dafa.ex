defmodule Kantele.Combat.Skills.HuagongDafa do
  @moduledoc """
  化功大法（对照 `kungfu/skill/huagong-dafa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 龟息功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格（光明磊落/狡黠多变）判定与「无性」性别限制
    未实现（本模型暂无性格/性别字段）。
  - `valid_damage` 被动（化功毒效 + freezing 状态）未接入。
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
    force = Stats.skill(stats, "force")
    poison = Stats.skill(stats, "poison")
    level = Stats.skill(stats, id())

    cond do
      stats.con < 30 ->
        {:error, "你试着运转了一下内力，登时觉得胸闷难耐！\n"}

      force < 120 ->
        {:error, "你的基本内功火候不足，不能学化功大法。\n"}

      poison < 120 ->
        {:error, "你的基本毒技火候不足，不能学化功大法。\n"}

      poison < level && level > 0 ->
        {:error, "你的基本毒技水平有限，不能领会更高深的化功大法。\n"}

      force < level && level > 0 ->
        {:error, "你的基本内功水平有限，不能领会更高深的化功大法。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)或练毒的来增加熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.HuagongDafa.Powerup}
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
