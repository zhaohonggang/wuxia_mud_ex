defmodule Kantele.Combat.Skills.LengyueShengong do
  @moduledoc """
  冷月神功（对照 `kungfu/skill/lengyue-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）；
    源文件技能查询误写为 `lenyue-shengong`（永不命中，失效代码）。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "lengyue-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.LengyueShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.LengyueShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/lengyue-shengong/powerup.c`）

  需 300 内力，耗 100；临时提升 attack=defense=冷月/3，持续 冷月 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "lengyue-shengong/powerup",
      gates: [
        {:neili_min, 300, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "lengyue-shengong"}, 3},
           defense: {:div, {:skill, "lengyue-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "lengyue-shengong"},
      expire_message: "你的冷月神功运行完毕，将内力收回丹田。\n",
      message: "$N全身关节“格啦格啦”一阵爆响，一股至阴的内劲从浑身经脉迸发出来。\n"
    }
end
