defmodule Kantele.Combat.Skills.HanbingZhenqi do
  @moduledoc """
  寒冰真气（对照 `kungfu/skill/hanbing-zhenqi.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 华山心法/衡山心法/嵩山心法/紫霞神功/镇岳诀 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili` 检查未实现。
  - `freezing`（寒冰真气）实现如下，需先 powerup、con>=34、skill>=140、max_neili>=2200、neili>=1000。
  - `hit_ob` 冰封被动未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hanbing-zhenqi"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "huashan-xinfa",
        "henshan-xinfa",
        "songshan-xinfa",
        "zixia-shengong",
        "zhenyue-jue"
      ]

  @impl true
  def valid_learn(stats) do
    force = Map.get(stats, "force") || Stats.skill(stats, "force")
    level = Map.get(stats, id()) || Stats.skill(stats, id())

    cond do
      force < 100 -> {:error, "你的基本内功火候不够，难以锻炼寒冰真气。\n"}
      force < level -> {:error, "你的基本内功水平不够，难以锻炼更深厚的寒冰真气。\n"}
      true -> :ok
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
      "powerup" => Kantele.Combat.Skills.HanbingZhenqi.Powerup,
      "freezing" => Kantele.Combat.Skills.HanbingZhenqi.Freezing
    }
  end
end

defmodule Kantele.Combat.Skills.HanbingZhenqi.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/hanbing-zhenqi/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=寒冰/3，持续 寒冰 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "hanbing-zhenqi/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "hanbing-zhenqi"}, 3},
           defense: {:div, {:skill, "hanbing-zhenqi"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "hanbing-zhenqi"},
      expire_message: "你的寒冰真气运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，默默运转体内所蓄的寒冰真气，霎时面部竟呈出一层薄霜。\n"
    }
end

defmodule Kantele.Combat.Skills.HanbingZhenqi.Freezing do
  @moduledoc """
  寒冰真气「freezing」（对照 `kungfu/skill/hanbing-zhenqi/freezing.c`）

  门槛：寒冰>=140、con>=34、max_neili>=2200、neili>=1000、
  需先 powerup 状态、非 freezing 状态。
  扣 neili 300，设 temp freezing，busy 3。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  @impl true
  def spec do
    %Spec{
      id: "hanbing-zhenqi/freezing",
      kind: :exert,
      gates: [
        {:skill_min, "hanbing-zhenqi", 140, "你的寒冰真气不够，难以施展「寒冰真气」。\n"},
        {:custom, &gate_con/1, "你的先天根骨不足，无法施展「寒冰真气」。\n"},
        {:max_neili_min, 2200, "你的内力修为不足，难以施展「寒冰真气」。\n"},
        {:custom, &gate_powerup/1, "你现在尚未曾运功，难以施展「寒冰真气」。\n"},
        {:neili_min, 1000, "你目前的内力不够，难以施展「寒冰真气」。\n"},
        {:no_buff, "freezing", "你现在正在施展「寒冰真气」。\n"}
      ],
      costs: %{neili: 300},
      effects: [
        {:custom, &effect_freezing/1}
      ],
      busy: 3,
      duration: {:skill, "hanbing-zhenqi"},
      expire_message: "你的「寒冰真气」运行完毕，将内力收回丹田。\n",
      message: "$N一声冷笑，体内寒冰真气迅速疾转数个周天，将力聚于掌心。\n"
    }
  end

  defp gate_con(ctx),
    do: ctx.character.meta.stats.con >= 34

  defp gate_powerup(ctx),
    do:
      ctx.character.meta.combat.buffs |> Enum.any?(&(&1.key == "powerup"))

  defp effect_freezing(state) do
    char = state.character

    new_combat =
      char.meta.combat
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "freezing",
        applies: %{},
        duration: Stats.skill(char.meta.stats, "hanbing-zhenqi")
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end
end