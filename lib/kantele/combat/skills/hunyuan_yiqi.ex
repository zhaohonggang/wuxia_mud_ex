defmodule Kantele.Combat.Skills.HunyuanYiqi do
  @moduledoc """
  混元一气功（对照 `kungfu/skill/hunyuan-yiqi.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 易筋经/太极神功/武当心法/少林心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「已婚（`couple/have_couple`）」与「非男性」限制
    分别按 `meta.spouse` / `meta.env[:gender]` 实装；
    「屡犯僧戒（`guilty`）」无对应字段，仍属引擎未建模层。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hunyuan-yiqi"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["yijinjing", "taiji-shengong", "wudang-xinfa", "shaolin-xinfa"]

  @impl true
  def valid_learn(stats, character) do
    buddhism = Stats.skill(stats, "buddhism")
    force = Stats.skill(stats, "force")
    level = Stats.skill(stats, id())

    cond do
      married?(character) ->
        {:error, "你已经破了色戒，无法再学习混元一气功！\n"}

      gender_of(character) != "男性" ->
        {:error, "你非童男之体，不能练习混元一气功。\n"}

      buddhism < 300 and buddhism < level ->
        {:error, "你的禅宗心法修为不够，无法领会更高深的混元一气功。\n"}

      force < 30 ->
        {:error, "你的基本内功火候还不够，无法学习混元一气功。\n"}

      force < level ->
        {:error, "你的基本内功火候还不够，无法领会更高深的混元一气功。\n"}

      true ->
        :ok
    end
  end

  # LPC `me->query("couple/have_couple")` → meta.spouse（已婚则 %{id:, name:}）
  defp married?(%{meta: %{spouse: %{id: id}}}) when not is_nil(id), do: true
  defp married?(_), do: false

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.HunyuanYiqi.Powerup}
  end
end

defmodule Kantele.Combat.Skills.HunyuanYiqi.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/hunyuan-yiqi/powerup.c`）

  需 150 内力方可发动，实际耗 100；临时提升 attack=defense=混元/3，
  持续 混元 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "hunyuan-yiqi/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "hunyuan-yiqi"}, 3},
           defense: {:div, {:skill, "hunyuan-yiqi"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "hunyuan-yiqi"},
      expire_message: "你的混元一气功运行完毕，将内力收回丹田。\n",
      message: "$N爆喝一声，浑身的骨骼哗啦哗啦一阵响，脸色变得赤红慑人。\n"
    }
end
