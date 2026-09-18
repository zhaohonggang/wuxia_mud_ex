defmodule Kantele.Combat.Skills.FreezingForce do
  @moduledoc """
  冰蚕寒功（对照 `kungfu/skill/freezing-force.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 龟息功/化功大法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 学习时删除已学的易筋经（副作用）未接入。
  - `hit_ob` 冰蚕寒劲被动（无兵器 + jiali + 目标 force 判定）未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "freezing-force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["guixi-gong", "huagong-dafa"]

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")
    level = Stats.skill(stats, id())

    cond do
      force < 50 -> {:error, "你的基本内功火候不够，难以锻炼冰蚕寒功！\n"}
      force < level -> {:error, "你的基本内功水平不够，难以锻炼更深厚的冰蚕寒功！\n"}
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
    %{"powerup" => Kantele.Combat.Skills.FreezingForce.Powerup}
  end
end

defmodule Kantele.Combat.Skills.FreezingForce.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/freezing-force/powerup.c`）

  需 200 内力，耗 100；临时提升 attack=defense=冰蚕/3，持续 冰蚕 秒；
  战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "freezing-force/powerup",
      gates: [
        {:neili_min, 200, "你的真气不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "freezing-force"}, 3},
           defense: {:div, {:skill, "freezing-force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "freezing-force"},
      expire_message: "你的冰蚕寒功运行完毕，将内力收回丹田。\n",
      message: "$N脸色一寒，一股煞气腾然而起，四下登时阴风瑟瑟，冷意惨惨。\n"
    }
end
