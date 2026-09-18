defmodule Kantele.Combat.Skills.ChangshengJue do
  @moduledoc """
  长生决（对照 `kungfu/skill/changsheng-jue.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 无条件接受其他内功共存（LPC `return 1`）。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「性格=狡黠多变」限制未实现（本模型暂无性格字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "changsheng-jue"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 35 -> {:error, "你觉得长生决过于艰深，难以理解。\n"}
      stats.con < 31 -> {:error, "依照你的根骨无法修炼长生决。\n"}
      Stats.skill(stats, "martial-cognize") < 300 -> {:error, "你的武学修养没有办法理解其中的精神奥义。\n"}
      true -> :ok
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
      "powerup" => Kantele.Combat.Skills.ChangshengJue.Powerup,
      "shield" => Kantele.Combat.Skills.ChangshengJue.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.ChangshengJue.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/changsheng-jue/powerup.c`）

  加成取**基本内功 force** 等级：attack=parry=dodge=force*2/5，耗 100 内力，
  持续 长生决 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "changsheng-jue/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:mul, {:skill, "force"}, 2}, 5},
           parry: {:div, {:mul, {:skill, "force"}, 2}, 5},
           dodge: {:div, {:mul, {:skill, "force"}, 2}, 5}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "changsheng-jue"},
      expire_message: "你的长生决运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起长生决，将真气凝聚在丹田之中，沿奇经八脉遍布全身！\n"
    }
end

defmodule Kantele.Combat.Skills.ChangshengJue.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/changsheng-jue/shield.c`）

  加成取**基本内功 force** 等级：armor=force*3，耗 100 内力，持续 长生决 秒；
  战斗中 busy 2 轮。

  差异：LPC `remove_effect` 实扣 `skill*2`（与施加的 `skill*3` 不对称，会残留
  armor），本引擎由 Buff.applies 精确回收，不复制该缺陷。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "changsheng-jue/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:mul, {:skill, "force"}, 3}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "changsheng-jue"},
      expire_message: "你的长生决运行完毕，将内力收回丹田。\n",
      message: "$N双手平举过顶，运起长生决内劲，全身笼罩在劲气之中！\n"
    }
end
