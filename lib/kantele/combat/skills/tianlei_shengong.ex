defmodule Kantele.Combat.Skills.TianleiShengong do
  @moduledoc """
  天雷神功（对照 `kungfu/skill/tianlei-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 铁掌心法/绝情心法/分心诀 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "tianlei-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["tiezhang-xinfa", "jueqing-xinfa", "fenxin-jue"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 70 do
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
    %{"powerup" => Kantele.Combat.Skills.TianleiShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.TianleiShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/tianlei-shengong/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=天雷/3、unarmed_damage=天雷/6，
  持续 天雷 秒；战斗中 busy 1..3 轮。

  注：LPC remove_effect 传 `skill/3` 后再对 unarmed_damage 减 `amount/2`，等价于本引擎按各原值精确回收。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "tianlei-shengong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "tianlei-shengong"}, 3},
           defense: {:div, {:skill, "tianlei-shengong"}, 3},
           unarmed_damage: {:div, {:skill, "tianlei-shengong"}, 6}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "tianlei-shengong"},
      expire_message: "你的天雷神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起天雷神功，真气顿时灌满全身，整个身体竟呈现出古铜色的光泽。\n"
    }
end
