defmodule Kantele.Combat.Skills.KurongChangong do
  @moduledoc """
  枯荣禅功（对照 `kungfu/skill/kurong-changong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 先天功/全真心法/玄门内功/段氏心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制（**无条件**拒绝）按 `meta.env[:gender]` 实装；
    引擎无 LPC `::valid_learn` 的父类附加检查（如 `can_learn` 系列），此层未迁移。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "kurong-changong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["xiantian-gong", "quanzhen-xinfa", "xuanmen-neigong", "duanshi-xinfa"]

  @impl true
  def valid_learn(_stats, character) do
    if gender_of(character) == "无性" do
      {:error, "你无根无性，阴阳不调，难以领会枯荣禅功。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.KurongChangong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.KurongChangong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/kurong-changong/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=枯荣/3，持续 枯荣 秒；
  战斗中 busy 1..3 轮。文案按修为分档（150/200/250），用 `message` 函数表达。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "kurong-changong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "kurong-changong"}, 3},
           defense: {:div, {:skill, "kurong-changong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "kurong-changong"},
      expire_message: "你的枯荣禅功运行完毕，将内力收回丹田。\n",
      message: fn ctx ->
        case Kantele.Character.Stats.skill(ctx.stats, "kurong-changong") do
          lvl when lvl > 250 ->
            "$N运起枯荣禅功，全身皮肤竟变得一半犹如婴儿，另一半却似干皱的树皮。\n"

          lvl when lvl > 200 ->
            "$N暗自凝神，运起枯荣禅功，全身皮肤竟变得犹如婴儿般光滑亮泽。\n"

          lvl when lvl > 150 ->
            "$N暗自凝神，运起枯荣禅功，全身皮肤竟变得犹如树皮般干皱苍老。\n"

          _ ->
            "$N暗自凝神，运起枯荣禅功，真气顿时游遍全身。\n"
        end
      end
    }
end
