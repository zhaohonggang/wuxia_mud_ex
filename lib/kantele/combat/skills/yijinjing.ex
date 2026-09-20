defmodule Kantele.Combat.Skills.Yijinjing do
  @moduledoc """
  易筋经神功（对照 `kungfu/skill/yijinjing.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 混元一气/太极神功/武当心法/少林心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别（必须男性）限制未实现（本模型暂无性别字段）。
  - LPC 注释掉的 `freezing-force` 互斥检查未实现。
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
    %{
      "powerup" => Kantele.Combat.Skills.Yijinjing.Powerup,
      "tong" => Kantele.Combat.Skills.Yijinjing.Tong
    }
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

defmodule Kantele.Combat.Skills.Yijinjing.Tong do
  @moduledoc """
  易筋通脉「tong」（对照 `kungfu/skill/yijinjing/tong.c`）

  自我疗伤：需易筋经 >=100、max_neili >=500、
  劲/气上限 ratio 介于 10%..80%（ratio = `eff_qi*100/max_qi`）、
  内力 >= `skill*5`。耗内力 `skill*4`、**永久扣 max_neili `skill/4`**、
  eff_qi 回复 `skill*8`（上限 max_qi）、qi 重置为 eff_qi；战斗中 busy 4。

  差异（TODO(migrate)）：
  - LPC 的 `can_perform/yijinjing/tong` 习得门控以 `Stats.perform_known?`
    表达；`max_neili` 永久扣减直接落在 vitals（持久化语义同 LPC add）。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "yijinjing/tong",
      kind: :exert,
      gates: [
        {:perform_known, "yijinjing/tong", "你所学的内功中没有这种功能。\n"},
        {:skill_min, "yijinjing", 100, "你的易筋经等级不够。\n"},
        {:max_neili_min, 500, "你的真气不够。\n"},
        {:custom, &gate_ratio_low/1, "你伤势很轻，不用激励易筋经至高绝学。\n"},
        {:custom, &gate_ratio_high/1, "你内伤太重，无法激励易筋经至高绝学。\n"},
        {:custom, &gate_neili/1, "你的真气不够。\n"}
      ],
      effects: [
        {:custom, &effect_tong/1}
      ],
      busy: {:if_fighting, 4},
      message:
        "$N默念易筋经的口诀：元气，气存于内，放于外。易筋，孕怀于息，舒于支……" <>
          "一股详和的白色罡气自头顶迅速游遍全身的奇经八脉！$N的内伤刹那间大为好转！！\n"
    }
  end

  # 门槛：eff_qi*100/max_qi > 80 视为伤势很轻
  defp gate_ratio_low(ctx) do
    ratio = eff_ratio(ctx.character.meta.vitals)
    ratio <= 80
  end

  # 门槛：ratio < 10 视为内伤太重
  defp gate_ratio_high(ctx) do
    ratio = eff_ratio(ctx.character.meta.vitals)
    ratio >= 10
  end

  defp gate_neili(ctx) do
    skill = Stats.skill(ctx.stats, "yijinjing")
    ctx.vitals.neili >= skill * 5
  end

  defp eff_ratio(vitals) do
    div(vitals.max_qi * 100, max(vitals.base_qi, 1))
  end

  defp effect_tong(state) do
    char = state.character
    vitals = char.meta.vitals
    skill = Stats.skill(char.meta.stats, "yijinjing")

    new_max_qi = min(vitals.max_qi + skill * 8, vitals.base_qi)

    vitals = %{
      vitals
      | neili: max(vitals.neili - skill * 4, 0),
        max_neili: max(vitals.max_neili - div(skill, 4), 1),
        max_qi: new_max_qi,
        qi: new_max_qi
    }

    %{state | character: %{char | meta: %{char.meta | vitals: vitals}}}
  end
end
