defmodule Kantele.Combat.Skills.LuohanFumogong do
  @moduledoc """
  罗汉伏魔神功（对照 `kungfu/skill/luohan-fumogong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，故恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili` 检查未实现。
  - powerup 的门派/物品门槛与分档文案未建模。
  - `fireice`（冰火九重天）需饮玄冰碧火酒/少林派、max_neili>=4000 等门槛，
    本实现仅保留等级/内力门槛，分歧标注。
  - `hit_ob` 被动未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "luohan-fumogong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 luohan-fumogong.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    gender = gender_of(character)
    personality = personality_of(character)

    cond do
      personality == "心狠手辣" ->
        {:error, "你心中暗道：此功一点气势也无，何苦费力学它。。\n"}

      personality == "阴险奸诈" ->
        {:error, "你心中暗道：此功平淡无奇，何苦为它花费心思。\n"}

      Stats.int(stats) < 30 ->
        {:error, "你先天悟性不足，难以领会罗汉伏魔神功。\n"}

      Stats.con(stats) < 30 ->
        {:error, "你先天根骨孱弱，无法修炼罗汉伏魔神功。\n"}

      (gender == "无性") and (Stats.skill(stats, "luohan-fumogong") > 29) ->
        {:error, "你无根无性，阴阳不调，难以领会高深的罗汉伏魔神功。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候不足，不能学罗汉伏魔神功。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力修为不足，不能学罗汉伏魔神功。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.LuohanFumogong.Powerup,
      "fireice" => Kantele.Combat.Skills.LuohanFumogong.Fireice
    }
  end

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil

end

defmodule Kantele.Combat.Skills.LuohanFumogong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/luohan-fumogong/powerup.c`）

  需 150 内力，耗 100；attack=defense=罗汉/3，持续 罗汉 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "luohan-fumogong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "luohan-fumogong"}, 3},
           defense: {:div, {:skill, "luohan-fumogong"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "luohan-fumogong"},
      expire_message: "你的罗汉伏魔神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起罗汉伏魔神功，全身肌肤竟交替呈现出靛青与血红两色。\n"
    }
end

defmodule Kantele.Combat.Skills.LuohanFumogong.Fireice do
  @moduledoc """
  执行「冰火九重天」（对照 `kungfu/skill/luohan-fumogong/fireice.c`）

  需 180 级、max_neili>=4000、500 内力，耗 300；
  armor=skill*2/5, damage=skill/5, unarmed_damage=skill/5，持续 skill 秒；busy 3。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "luohan-fumogong/fireice",
      gates: [
        {:skill_min, "luohan-fumogong", 180, "你罗汉伏魔功火候不足，难以施展「冰火九重天」。\n"},
        {:max_neili_min, 4000, "你的内力修为不足，难以施展「冰火九重天」。\n"},
        {:neili_min, 500, "你现在的内力不足，难以施展「冰火九重天」。\n"},
        {:no_buff, "fireice", "你现在正在施展「冰火九重天」。\n"}
      ],
      costs: %{neili: 300},
      effects: [
        {:buff, "fireice",
         %{
           armor: {:div, {:mul, {:skill, "luohan-fumogong"}, 2}, 5},
           damage: {:div, {:skill, "luohan-fumogong"}, 5},
           unarmed_damage: {:div, {:skill, "luohan-fumogong"}, 5}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "luohan-fumogong"},
      expire_message: "你的「冰火九重天」运行完毕，将内力收回丹田。\n",
      message: "$N纵声长啸，运转「冰火九重天」真气，聚力于掌间，光华流动，煞为壮观。\n"
    }
end
