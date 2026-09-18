defmodule Kantele.Combat.Skills.BahuangGong do
  @moduledoc """
  八荒六合唯我独尊功（对照 `kungfu/skill/bahuang-gong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练（LPC `practice_skill` 拒绝）。
  `valid_force` 接受 逍遥心法/灵鹫心法/北冥神功/小无相功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 另有「无性」性别限制与 `::valid_learn` 基本上限，
    本模型暂无性别字段，未实现。
  - LPC `query_neili_improve`（内力上限成长公式）未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bahuang-gong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["xiaoyao-xinfa", "lingjiu-xinfa", "beiming-shengong", "xiaowuxiang"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 80 do
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
    %{
      "powerup" => Kantele.Combat.Skills.BahuangGong.Powerup,
      "shield" => Kantele.Combat.Skills.BahuangGong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.BahuangGong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/bahuang-gong/powerup.c`）

  耗 100 内力，临时提升 attack=八荒/2、dodge=parry=八荒/3，持续 八荒 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "bahuang-gong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "bahuang-gong"}, 2},
           dodge: {:div, {:skill, "bahuang-gong"}, 3},
           parry: {:div, {:skill, "bahuang-gong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "bahuang-gong"},
      expire_message: "你的八荒六合唯我独尊功运行完毕，将内力收回丹田。\n",
      message: "$N凝神息气，运起八荒六合唯我独尊功，只见一股轻烟悄然缭绕周身。\n"
    }
end

defmodule Kantele.Combat.Skills.BahuangGong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/bahuang-gong/shield.c`）

  需八荒 ≥50，耗 100 内力，临时提升 armor=八荒/2，持续 八荒 秒；
  战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "bahuang-gong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "bahuang-gong", 50, "你的八荒六合唯我独尊功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "bahuang-gong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "bahuang-gong"},
      expire_message: "你的八荒六合唯我独尊功运行完毕，将内力收回丹田。\n",
      message: "$N双手平举过顶，运起八荒六合唯我独尊功功，全身顿时笼罩在劲气之中！\n"
    }
end
