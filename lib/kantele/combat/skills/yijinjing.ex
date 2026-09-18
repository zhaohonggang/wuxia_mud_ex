defmodule Kantele.Combat.Skills.Yijinjing do
  @moduledoc """
  易筋经神功（对照 `kungfu/skill/yijinjing.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 混元一气/太极神功/武当心法/少林心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别（必须男性）限制未实现（本模型暂无性别字段）。
  - LPC 注释掉的 `freezing-force` 互斥检查未实现。
  - `tong` (易筋通脉) 涉及动态内力消耗、劲/气比例门槛、永久扣 `max_neili` 与 `eff_qi` 回复上限
    等复杂逻辑，标记为手写差异项，暂不建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "yijinjing"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["hunyuan-yiqi", "taiji-shengong", "wudang-xinfa", "shaolin-xinfa"]

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")
    level = Stats.skill(stats, id())

    cond do
      force < 100 ->
        {:error, "你的基本内功火候不够，无法学习易筋经神功！\n"}

      force < level ->
        {:error, "你的基本内功水平不够，难以领悟更高深的易筋经神功！\n"}

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
    %{"powerup" => Kantele.Combat.Skills.Yijinjing.Powerup}
  end
end

defmodule Kantele.Combat.Skills.Yijinjing.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/yijinjing/powerup.c`）

  需 200 内力，耗 100；临时提升 attack=defense=易筋/3，持续 易筋 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "yijinjing/powerup",
      gates: [
        {:neili_min, 200, "你的真气不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "yijinjing"}, 3},
           defense: {:div, {:skill, "yijinjing"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "yijinjing"},
      expire_message: "你的易筋经神功运行完毕，将内力收回丹田。\n",
      message: "$N淡淡一笑，脸现慈和之意，衣裳无风自动，似乎有一股气流回旋。\n"
    }
end
