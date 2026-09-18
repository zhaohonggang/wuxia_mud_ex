defmodule Kantele.Combat.Skills.ZixiaShengong do
  @moduledoc """
  紫霞神功（对照 `kungfu/skill/zixia-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 华山心法/衡山心法/嵩山心法/寒冰真气/镇岳诀 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制块源文件已注释，故未实装。
  - `query_neili_improve` / `difficult_level` 按辟邪剑法分档的成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "zixia-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "huashan-xinfa",
        "henshan-xinfa",
        "songshan-xinfa",
        "hanbing-zhenqi",
        "zhenyue-jue"
      ]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 60 do
      {:error, "你的基本内功火候还不够，还不能学习紫霞神功。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.ZixiaShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.ZixiaShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/zixia-shengong/powerup.c`）

  耗 100 内力，临时提升 attack=defense=紫霞/3，持续 紫霞 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "zixia-shengong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "zixia-shengong"}, 3},
           defense: {:div, {:skill, "zixia-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "zixia-shengong"},
      expire_message: "你的紫霞神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起紫霞神功，背转身去，脸上突然紫气大盛！只是那紫气一现即隐，\n转过身来，脸上又回复如常。\n"
    }
end
