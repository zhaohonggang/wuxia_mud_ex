defmodule Kantele.Combat.Skills.Xiaowuxiang do
  @moduledoc """
  小无相功（对照 `kungfu/skill/xiaowuxiang.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 逍遥心法/北冥神功/八荒六合唯我独尊功/灵鹫心法/密宗内功/
  血刀大法/龙象功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xiaowuxiang"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "xiaoyao-xinfa",
        "beiming-shengong",
        "bahuang-gong",
        "lingjiu-xinfa",
        "mizong-neigong",
        "xuedao-dafa",
        "longxiang-gong"
      ]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 80 do
      {:error, "你的基本内功火候不足，不能学小无相功。\n"}
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
      "powerup" => Kantele.Combat.Skills.Xiaowuxiang.Powerup,
      "shield" => Kantele.Combat.Skills.Xiaowuxiang.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.Xiaowuxiang.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xiaowuxiang/powerup.c`）

  耗 100 内力，临时提升 attack=parry=dodge=小无相/3，持续 小无相 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xiaowuxiang/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xiaowuxiang"}, 3},
           parry: {:div, {:skill, "xiaowuxiang"}, 3},
           dodge: {:div, {:skill, "xiaowuxiang"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "xiaowuxiang"},
      expire_message: "你的小无相功运行完毕，将内力收回丹田。\n",
      message: "$N脸色一寒、如罩白霜，拂袖傲然而立，宛若得道真仙。\n"
    }
end

defmodule Kantele.Combat.Skills.Xiaowuxiang.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/xiaowuxiang/shield.c`）

  需小无相 ≥40，耗 100 内力，临时提升 armor=小无相/2，持续 小无相 秒；
  战斗中 busy 2 轮。

  注：LPC 修为不足的文案误写为「你的内力不够。」（与内力门槛同文），此处照抄。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xiaowuxiang/shield",
      gates: [
        {:neili_min, 100, "你的真气不够。\n"},
        {:skill_min, "xiaowuxiang", 40, "你的内力不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "xiaowuxiang"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "xiaowuxiang"},
      expire_message: "你的小无相功运行完毕，将内力收回丹田。\n",
      message: "$N双手平举过顶，运起小无相功，全身笼罩在劲气之中！\n"
    }
end
