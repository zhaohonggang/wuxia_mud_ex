defmodule Kantele.Combat.Skills.YunvXinjing do
  @moduledoc """
  玉女心经（对照 `kungfu/skill/yunv-xinjing.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 素心诀/玄门内功/先天功/全真心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制与 `max_neili>=2000` 检查
    （`valid_learn/1` 仅有 stats，无 vitals）未实现。
  - `hit_ob` 被动（剑/鞭额外伤害）未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "yunv-xinjing"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["suxin-jue", "xuanmen-neigong", "xiantian-gong", "quanzhen-xinfa"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的基本内功火候还不够，不能修习玉女心经。\n"}

      stats.int < 32 ->
        {:error, "你的先天悟性不足，无法领悟玉女心经。\n"}

      true ->
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
    %{"powerup" => Kantele.Combat.Skills.YunvXinjing.Powerup}
  end
end

defmodule Kantele.Combat.Skills.YunvXinjing.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/yunv-xinjing/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=玉女/3，持续 玉女 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "yunv-xinjing/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "yunv-xinjing"}, 3},
           defense: {:div, {:skill, "yunv-xinjing"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "yunv-xinjing"},
      expire_message: "你的玉女心经运行完毕，将内力收回丹田。\n",
      message: "$N脸色微微一沉，默运玉女心经，双掌向外一分，姿势曼妙之极。\n"
    }
end
