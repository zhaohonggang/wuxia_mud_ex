defmodule Kantele.Combat.Skills.YijinDuangu do
  @moduledoc """
  易筋锻骨内功（对照 `kungfu/skill/yijin-duangu.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格（心狠手辣/狡黠多变/阴险奸诈）判定、
    「无性」性别限制、`query("yijin-duangu",1)` 误用（永不触发）未实现。
  - LPC 拥有 `query_action` 返回固定动作描述（unarmed 风格），本模型返回空。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "yijin-duangu"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你觉得自己先天根骨不足，一时难以修炼。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候还不够，还不能学习易筋锻骨内功。\n"}

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
    %{"powerup" => Kantele.Combat.Skills.YijinDuangu.Powerup}
  end
end

defmodule Kantele.Combat.Skills.YijinDuangu.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/yijin-duangu/powerup.c`）

  取**基本 force** 等级：需 100 内力，耗 100；仅临时提升 attack=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "yijin-duangu/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的功力运行完毕，将内力收回丹田。\n",
      message: "$N暗自凝神，提运九阴真气，全身渐渐升起一层白雾。\n"
    }
end
