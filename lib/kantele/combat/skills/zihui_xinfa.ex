defmodule Kantele.Combat.Skills.ZihuiXinfa do
  @moduledoc """
  紫徽心法（对照 `kungfu/skill/zihui-xinfa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 慕容心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "zihui-xinfa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "murong-xinfa"

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 20 do
      {:error, "你的基本内功火候还不够，还不能学习紫徽心法。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.ZihuiXinfa.Powerup}
  end
end

defmodule Kantele.Combat.Skills.ZihuiXinfa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/zihui-xinfa/powerup.c`）

  需 100 内力，耗 100；attack=dodge=defense=紫徽/3，持续 紫徽 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "zihui-xinfa/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "zihui-xinfa"}, 3},
           dodge: {:div, {:skill, "zihui-xinfa"}, 3},
           defense: {:div, {:skill, "zihui-xinfa"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "zihui-xinfa"},
      expire_message: "你的紫徽心法运行完毕，将内力收回丹田。\n",
      message: "$N一声长啸，脚下按北斗方位连踏七步，身形急转、飘洒之极！\n"
    }
end
