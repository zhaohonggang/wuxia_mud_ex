defmodule Kantele.Combat.Skills.XuantianWujigong do
  @moduledoc """
  玄天无极功（对照 `kungfu/skill/xuantian-wujigong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 天幻神诀/无争心法/日月心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制按 `meta.env[:gender]` 实装（>19 级拒绝）；
    引擎无 LPC `::valid_learn` 的父类附加检查（`can_learn` 系列），此层未迁移。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xuantian-wujigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["tianhuan-shenjue", "wuzheng-xinfa", "riyue-xinfa"]

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())

    cond do
      gender_of(character) == "无性" and lvl > 19 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的玄天无极功。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的基本内功火候还不够。\n"}

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
    %{
      "powerup" => Kantele.Combat.Skills.XuantianWujigong.Powerup,
      "shield" => Kantele.Combat.Skills.XuantianWujigong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.XuantianWujigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xuantian-wujigong/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=玄天/3，持续 玄天 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xuantian-wujigong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xuantian-wujigong"}, 3},
           defense: {:div, {:skill, "xuantian-wujigong"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "xuantian-wujigong"},
      expire_message: "你的玄天无极功运行完毕，将内力收回丹田。\n",
      message: "$N凝神聚气，运起玄天无极功，真气注满全身，全身竟然笼罩了一层薄薄的寒霜。\n"
    }
end

defmodule Kantele.Combat.Skills.XuantianWujigong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/xuantian-wujigong/shield.c`）

  需玄天 ≥50，耗 100 内力，临时提升 armor=玄天/2，持续 玄天 秒；战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xuantian-wujigong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "xuantian-wujigong", 50, "你的玄天无极功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "xuantian-wujigong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "xuantian-wujigong"},
      expire_message: "你的玄天无极功运行完毕，将内力收回丹田。\n",
      message: "$N大喝一声，玄天无极真气由体内迸发而出，顿时一股极寒罡劲笼罩全身。\n"
    }
end
