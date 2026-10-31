defmodule Kantele.Combat.Skills.TianhuanShenjue do
  @moduledoc """
  天寰神诀（对照 `kungfu/skill/tianhuan-shenjue.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 无嗔心法/玄天无极功/日月心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制按 `meta.env[:gender]` 实装（>99 级拒绝，
    日月神教内功故阈值放宽）；
    引擎无 LPC `::valid_learn` 的父类附加检查（`can_learn` 系列），此层未迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "tianhuan-shenjue"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["wuzheng-xinfa", "xuantian-wujigong", "riyue-xinfa"]

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "force") < 50 ->
        {:error, "你的基本内功火候还不够。\n"}

      gender_of(character) == "无性" and lvl > 99 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的天寰神诀。\n"}

      true ->
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
    %{"powerup" => Kantele.Combat.Skills.TianhuanShenjue.Powerup}
  end
end

defmodule Kantele.Combat.Skills.TianhuanShenjue.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/tianhuan-shenjue/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=天寰/3，持续 天寰 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "tianhuan-shenjue/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "tianhuan-shenjue"}, 3},
           defense: {:div, {:skill, "tianhuan-shenjue"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "tianhuan-shenjue"},
      expire_message: "你的天寰神诀运行完毕，将内力收回丹田。\n",
      message: "$N纵声长啸，体内真气急剧运转，引得周围气流随之荡漾。\n"
    }
end
