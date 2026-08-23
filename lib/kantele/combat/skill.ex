defmodule Kantele.Combat.Skill do
  @moduledoc """
  武学 behaviour（对应 LPC `inherit/skill/skill.c` 的契约点）

  招式表存数据（实现模块的 `@actions` module attribute），公式存代码。

  # 实现

      defmodule MySkill do
        use Kantele.Combat.Skill

        @actions [
          %{"action" => "...", "force" => 80, "attack" => 25, "dodge" => 10,
            "parry" => 15, "damage" => 8, "lvl" => 0,
            "damage_type" => "刺伤", "skill_name" => "杨柳依依"}
        ]

        def id, do: "my-skill"
        def valid_enable("sword"), do: true
        def valid_enable(_), do: false
      end

  招式表字段与 LPC 完全一致（八字段）：action/force/attack/dodge/parry/
  damage/lvl/damage_type/skill_name。
  """

  alias Kantele.Character.Stats

  @type rng :: (pos_integer() -> pos_integer())

  @callback id() :: String.t()

  @doc "是否可 enable 到某用法（valid_enable/1）"
  @callback valid_enable(String.t()) :: boolean()

  @doc "学习门槛校验（valid_learn/1）"
  @callback valid_learn(Stats.t()) :: :ok | {:error, String.t()}

  @doc "练习一次的消耗（practice_skill 的 qi/neili 消耗）"
  @callback practice_cost() :: %{qi: non_neg_integer(), neili: non_neg_integer()}

  @doc "按等级加权随机选一招（query_action + NewRandom）"
  @callback query_action(non_neg_integer()) :: map()
  @callback query_action(non_neg_integer(), rng()) :: map()

  @doc "绝招列表：短名 -> 实现 module（perform_action_file 映射）"
  @callback perform_list() :: %{String.t() => module()}

  @doc "运功列表：功能名 -> 实现 module（exert_function_file 映射）"
  @callback exert_list() :: %{String.t() => module()}

  @optional_callbacks [perform_list: 0, exert_list: 0]

  defmacro __using__(_opts) do
    quote do
      @behaviour Kantele.Combat.Skill

      import Kantele.Combat.Skill, only: [new_random: 1, new_random: 2]

      @doc false
      def valid_learn(_stats), do: :ok

      @doc false
      def practice_cost(), do: %{qi: 50, neili: 30}

      @doc false
      def perform_list(), do: %{}

      @doc false
      def exert_list(), do: %{}

      defoverridable valid_learn: 1, practice_cost: 0, perform_list: 0, exert_list: 0
    end
  end

  @doc """
  从招式表中按等级选出可用招式并加权抽取一式

  对照 LPC：

      for (i = sizeof(action); i > 0; i--)
          if (level > action[i-1]["lvl"])
              return action[NewRandom(i, 20, level/5)];
  """
  @spec pick_action([map()], non_neg_integer(), rng()) :: map()
  def pick_action(actions, level, rng \\ &:rand.uniform/1) do
    count =
      Enum.count(actions, fn action ->
        level > Map.get(action, "lvl", 0)
      end)

    case count do
      0 -> List.first(actions) || %{}
      count -> Enum.at(actions, new_random(count, rng))
    end
  end

  @doc """
  LPC NewRandom 加权随机：越靠后的招式权重越大

  精确移植 `inherit/skill/skill.c#NewRandom/3`（base/d 参数未参与计算，省略）
  """
  @spec new_random(non_neg_integer(), rng()) :: non_neg_integer()
  def new_random(n, rng \\ &:rand.uniform/1) when n >= 0 do
    k = min(6, n)

    case k do
      0 ->
        n

      _ ->
        sum = div(k * (k - 1), 2)
        walk(n, k, rand(rng, sum), 0)
    end
  end

  defp walk(n, k, remaining, i) when i < k do
    if remaining - i <= 0 do
      max(n - k + i, 0)
    else
      walk(n, k, remaining - i, i + 1)
    end
  end

  defp walk(n, _k, _remaining, _i), do: n

  defp rand(_rng, n) when n < 1, do: 0
  defp rand(rng, n), do: rng.(n) - 1
end
