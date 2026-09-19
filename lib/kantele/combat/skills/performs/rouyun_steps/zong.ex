defmodule Kantele.Combat.Skills.Performs.RouyunSteps.Zong do
  @moduledoc """
  柔云纵「zong」（对照 `kungfu/skill/rouyun-steps/zong.c`）

  移动绝招：`rouyun-steps >= 50`，施放后在原地广播一段
  「身形陡然纵起…乘云而去了」文案，随即随机传送至三个预设房间之一
  （wumiao/kedian/workroom）。无内力消耗、busy 0。

  LPC `me->move(env)` 使角色瞬移并自动进出房间广播；本引擎以自定义效果
  直接改写 `state.character.room_id`，仅保留原地（旧房间）的起步文案，
  来访玩家需等房间内玩家加入后再触发 `room/enter` 广播。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Combat.Performs.Spec, as: Spec

  @name "「柔云纵」"

  @dest_rooms [
    # LPC /d/city/wumiao
    "city/wumiao",
    # LPC /d/city/kedian
    "city/kedian",
    # LPC /u/mudren/workroom
    "mudren/workroom"
  ]

  def spec do
    %Spec{
      id: "rouyun-steps/zong",
      kind: :perform,
      gates: [
        {:perform_known, "rouyun-steps/zong", "你所使用的外功中没有这种功能。\n"},
        {:skill_min, "rouyun-steps", 50, "你的柔云步法不够熟练！\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_zong/1}
      ],
      busy: 0,
      message: "$N身形陡然纵起，十分优雅，天空中却飘下一朵云，非常奇怪！\n原来$N已使出#{@name}，乘云而去了！\n"
    }
  end

  defp effect_zong(state) do
    dest = Enum.random(@dest_rooms)
    character = %{state.character | room_id: dest}

    %{state | character: character}
  end
end