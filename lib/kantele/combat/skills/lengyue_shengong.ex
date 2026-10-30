defmodule Kantele.Combat.Skills.LengyueShengong do
  @moduledoc """
  冷月神功（对照 `kungfu/skill/lengyue-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性 & 等级 > 49」门**原样保真（含 bug）**：LPC 把等级查询误写为
    `lenyue-shengong`（少一个 `g`），该技能不存在、恒返回 0，故门永不触发。此处照抄同一
    错误 id，行为与 LPC 完全一致；若日后修正拼写，需同步放开此门。
  - 引擎无 LPC `::valid_learn` 的父类附加检查（如 `can_learn` 系列），此层未迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "lengyue-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats, character) do
    # LPC 原样：查询的是拼错的 "lenyue-shengong"，恒为 0，故此门永不触发。
    if gender_of(character) == "无性" and Stats.skill(stats, "lenyue-shengong") > 49 do
      {:error, "你无根无性，阴阳不调，难以领会高深的冷月神功。\n"}
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
