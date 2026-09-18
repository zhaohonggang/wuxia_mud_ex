defmodule Kantele.Combat.Skills.HuntianQigong do
  @moduledoc """
  混天气功（对照 `kungfu/skill/huntian-qigong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 叫花内功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huntian-qigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "jiaohua-neigong"

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 30 do
      {:error, "你的基本内功火候不够，无法学习混天气功。\n"}
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
    %{
      "powerup" => Kantele.Combat.Skills.HuntianQigong.Powerup,
      "shield" => Kantele.Combat.Skills.HuntianQigong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.HuntianQigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/huntian-qigong/powerup.c`）

  取**基本 force** 等级：耗 100 内力，临时提升 attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "huntian-qigong/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够。\n"},
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
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "force"},
      expire_message: "你的混天气功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起混天气功，全身骨节发出一阵爆豆般的声响。\n"
    }
end

defmodule Kantele.Combat.Skills.HuntianQigong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/huntian-qigong/shield.c`）

  需混天 ≥200，耗 100 内力，持续 混天+占验+叫化 秒；战斗中 busy 2 轮。

  差异：LPC 以 `add_temp("str", …)`/`add_temp("dex", …)` 提升先天属性
  （非 `apply/*` 临时键），本引擎未建模 str/dex 临时属性，故本 buff 无数值
  加成，仅保留状态与到期回收。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "huntian-qigong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "huntian-qigong", 200, "你的混天气功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [{:buff, "shield", %{}}],
      busy: {:if_fighting, 2},
      duration:
        {:add, {:skill, "huntian-qigong"}, {:add, {:skill, "checking"}, {:skill, "begging"}}},
      expire_message: "你的混天气功运行完毕，白色的薄雾渐渐散去。\n",
      message: "$N使出混天气功绝学「混元天罡」，一股白气自顶心泥丸发散而下，全身弥漫在白色薄雾中！\n"
    }
end
