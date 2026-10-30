defmodule Kantele.Combat.Skills.DuanshiXinfa do
  @moduledoc """
  段氏心法（对照 `kungfu/skill/duanshi-xinfa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 先天功/全真心法/玄门内功/枯荣禅功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性 & 等级 > 49」性别限制按 `meta.env[:gender]` 实装；
    引擎无 LPC `::valid_learn` 的父类附加检查（如 `can_learn` 系列），此层未迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanshi-xinfa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["xiantian-gong", "quanzhen-xinfa", "xuanmen-neigong", "kurong-changong"]

  @impl true
  def valid_learn(stats, character) do
    if gender_of(character) == "无性" and Stats.skill(stats, id()) > 49 do
      {:error, "你无根无性，阴阳不调，难以领会高深的段氏心法。\n"}
    else
      :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.DuanshiXinfa.Powerup}
  end
end

defmodule Kantele.Combat.Skills.DuanshiXinfa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/duanshi-xinfa/powerup.c`）

  取**基本 force** 等级：需 150 内力，耗 50；临时提升
  attack=defense=基本内功/5，持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "duanshi-xinfa/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 50},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 5},
           defense: {:div, {:skill, "force"}, 5}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的段氏心法运行完毕，将内力收回丹田。\n",
      message: "$N暗自凝神，运起段氏心法，脸上显出一股祥和之意，颇具王者风范。\n"
    }
end
