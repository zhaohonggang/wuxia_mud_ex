defmodule Kantele.Combat.Skills.LinjiZhuang do
  @moduledoc """
  临济十二庄（对照 `kungfu/skill/linji-zhuang.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 武当心法/峨眉心法/太极神功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别（必须女性）限制、`mahayana` 等级与 `np <= nh` 判定、
    以及分层名称（天地/之心/龙鹏/风云/大小/幽冥庄）未实现。
  - powerup 中 `di` 计算依赖性别与 `mahayana`（`me->query("sex")` 判定），
    本模型简化为 `di = skill/2 + skill2/10`（封顶 100）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "linji-zhuang"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["wudang-xinfa", "emei-xinfa", "taiji-shengong"]

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")
    level = Stats.skill(stats, id())
    mahayana = Stats.skill(stats, "mahayana")

    cond do
      force < 40 ->
        {:error, "你的基本内功火候还不够，无法领会临济十二庄。\n"}

      mahayana < level && mahayana < 200 ->
        {:error, "你的大乘涅磐功修为不够，无法领会更高深的临济十二庄。\n"}

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
    %{"powerup" => Kantele.Combat.Skills.LinjiZhuang.Powerup}
  end
end

defmodule Kantele.Combat.Skills.LinjiZhuang.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/linji-zhuang/powerup.c`）

  需 100 内力，耗 100；attack=linji/3, dodge=linji/3, damage=di，
  其中 di = linji/2 + mahayana/10（封顶 100）；持续 linji 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "linji-zhuang/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "linji-zhuang"}, 3},
           dodge: {:div, {:skill, "linji-zhuang"}, 3},
           damage: {:add, {:div, {:skill, "linji-zhuang"}, 2}, {:div, {:skill, "mahayana"}, 10}}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "linji-zhuang"},
      expire_message: "你的临济庄运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起临济庄，一声娇喝，四周的空气仿佛都凝固了！\n"
    }
end
