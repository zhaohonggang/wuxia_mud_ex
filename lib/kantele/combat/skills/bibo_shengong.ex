defmodule Kantele.Combat.Skills.BiboShengong do
  @moduledoc """
  碧波神功（对照 `kungfu/skill/bibo-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 落英心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制按 `meta.env[:gender]` 实装（>49 级拒绝）；
    引擎无 LPC `::valid_learn` 的父类附加检查（`can_learn` 系列），此层未迁移。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bibo-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "luoying-xinfa"

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())

    cond do
      gender_of(character) == "无性" and lvl > 49 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的碧波神功。\n"}

      Stats.skill(stats, "chuixiao-jifa") < 100 ->
        {:error, "你没有精通吹箫技法，无法领会碧波神功的奥秘。\n"}

      true ->
        :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "只能学(learn)或从运功中长熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.BiboShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.BiboShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/bibo-shengong/powerup.c`）

  门槛（按 .c 顺序）：目标为自身 → 真气>=100 → 未在运功。
  扣 100 真气；attack=defense=碧波/3，持续 碧波 秒；
  战斗中 busy `1+random(3)`；到期回收。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "bibo-shengong/powerup",
      gates: [
        # LPC: if (target != me) return notify_fail("你只能用碧波神功提升自己的战斗力。\n");
        # exert 恒以自身为目标，此门槛恒真，仅保留文案以对齐 .c。
        {:custom, fn _ -> true end, "你只能用碧波神功提升自己的战斗力。\n"},
        {:neili_min, 100, "你的真气不够！\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "bibo-shengong"}, 3},
           defense: {:div, {:skill, "bibo-shengong"}, 3}
         }}
      ],
      # {:random, min, max} 含端点，故 {:random, 1, 3} 即 LPC 的 1 + random(3)
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "bibo-shengong"},
      expire_message: "你的碧波神功运行完毕，将内力收回丹田。\n",
      message: "$N仰天一声清啸，全身衣袍顿时如巨涛般向四面扩涨。\n"
    }
end
