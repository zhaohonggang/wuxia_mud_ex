defmodule Kantele.Combat.Skills.RouyunSteps do
  @moduledoc """
  柔云步（对照 `kungfu/skill/rouyun-steps.c`）

  轻功载体：`valid_enable("dodge")`、`valid_enable("move")`。

  差异（TODO(migrate)）：
  - LPC `query_action` 返回移动动作，本模型未实现。
  - `zong`（柔云纵）为随机传送技能，目标为随机房间。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "rouyun-steps"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zong" => Kantele.Combat.Skills.RouyunSteps.Zong}
  end
end

defmodule Kantele.Combat.Skills.RouyunSteps.Zong do
  @moduledoc """
  柔云纵「zong」（对照 `kungfu/skill/rouyun-steps/zong.c`）

  移动技能：需 50 级，随机传送至预设房间之一。
  无内力消耗，busy 0。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "rouyun-steps"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zong" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "rouyun-steps/zong",
      kind: :perform,
      gates: [
        {:skill_min, "rouyun-steps", 50, "你的柔云步法不够熟练！\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_zong/1}
      ],
      busy: 0,
      message: fn _ctx ->
        dest_rooms = [
          "city/wumiao",
          "city/kedian",
          "mudren/workroom"
        ]

        dest = Enum.random(dest_rooms)
        "$N身形陡然纵起，十分优雅，天空中却飘下一朵云，非常奇怪！\n原来$N已使出「柔云纵」，乘云而去了！\n"
      end
    }
  end

  defp effect_zong(state) do
    dest_rooms = [
      "city/wumiao",
      "city/kedian",
      "mudren/workroom"
    ]

    dest = Enum.random(dest_rooms)
    char = state.character
    new_char = %{char | meta: %{char.meta | room_id: dest}}
    %{state | character: new_char}
  end
end
