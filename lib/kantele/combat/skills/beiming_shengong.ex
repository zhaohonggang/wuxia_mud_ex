defmodule Kantele.Combat.Skills.BeimingShengong do
  @moduledoc """
  北冥神功（对照 `kungfu/skill/beiming-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 逍遥心法/灵鹫心法/八荒六合唯我独尊功/小无相功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - LPC `valid_damage`（等级 ≥70 时概率吸取对方加力内力、免疫伤害）
    未实现；`query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "beiming-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["xiaoyao-xinfa", "lingjiu-xinfa", "bahuang-gong", "xiaowuxiang"]

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 32 -> {:error, "你觉得北冥神功艰深无比，难以领会。\n"}
      stats.con < 24 -> {:error, "你试着运转了一下内力，眼前登时一黑！\n"}
      true -> :ok
    end
  end

  @doc "只能学(learn)或从运功中长熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.BeimingShengong.Powerup,
      "shield" => Kantele.Combat.Skills.BeimingShengong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.BeimingShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/beiming-shengong/powerup.c`）

  需 500 内力方可发动，实际耗 100；临时提升 attack=defense=北冥/3，
  持续 北冥 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "beiming-shengong/powerup",
      gates: [
        {:neili_min, 500, "你的内力不够!"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "beiming-shengong"}, 3},
           defense: {:div, {:skill, "beiming-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "beiming-shengong"},
      expire_message: "你的北冥神功运行完毕，将内力收回丹田。\n",
      message: "$N将内力运遍浑身诸大要穴，然后收气丹田，双目一睁，登时精光四射！\n"
    }
end

defmodule Kantele.Combat.Skills.BeimingShengong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/beiming-shengong/shield.c`）

  需北冥 ≥50，耗 100 内力，临时提升 armor=北冥/2，持续 北冥 秒；
  战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "beiming-shengong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "beiming-shengong", 50, "你的北冥神功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "beiming-shengong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "beiming-shengong"},
      expire_message: "你的北冥神功运行完毕，将内力收回丹田。\n",
      message: "$N双手平举过顶，运起北冥神功，全身笼罩在劲气之中！\n"
    }
end
