defmodule Kantele.Combat.Skills.XuanmingShengong do
  @moduledoc """
  玄冥神功（对照 `kungfu/skill/xuanming-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 冥谷心法 共存。

  差异（TODO(migrate)）：
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xuanming-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "minggu-xinfa"

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 32 -> {:error, "你先天根骨不足，无法修炼玄冥神功。\n"}
      Stats.skill(stats, "force") < 100 -> {:error, "你的基本内功火候还不够，还不能学习玄冥神功。\n"}
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
      "powerup" => Kantele.Combat.Skills.XuanmingShengong.Powerup,
      "shield" => Kantele.Combat.Skills.XuanmingShengong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.XuanmingShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xuanming-shengong/powerup.c`）

  耗 100 内力，临时提升 attack=defense=玄冥/3，持续 玄冥 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xuanming-shengong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xuanming-shengong"}, 3},
           defense: {:div, {:skill, "xuanming-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "xuanming-shengong"},
      expire_message: "你的玄冥神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起玄冥神功，全身顿时升起一层氤氲寒气，将$N笼罩其中。\n"
    }
end

defmodule Kantele.Combat.Skills.XuanmingShengong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/xuanming-shengong/shield.c`）

  需玄冥 ≥100，耗 100 内力，临时提升 armor=玄冥/2，持续 玄冥 秒；战斗中 busy 2 轮。

  差异：LPC 另加 `apply/strike`（玄冥/8）增强掌法，本引擎临时加成键未建模
  `strike`（与 `force/power` 的处理一致），仅落 armor。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xuanming-shengong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "xuanming-shengong", 100, "你的玄冥神功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "xuanming-shengong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "xuanming-shengong"},
      expire_message: "你的玄冥神功运行完毕，将内力收回丹田。\n",
      message: "$N深深吸了一口气，缓缓吐出，一股白烟冉冉透体而出，盘旋笼罩了全身。\n"
    }
end
