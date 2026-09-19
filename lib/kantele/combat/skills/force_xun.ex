defmodule Kantele.Combat.Skills.Force.Xun do
  @moduledoc """
  寻踪（对照 `kungfu/skill/force/xun.c`）

  仅限 wiz_test 权限且有 quest/id 的玩家；不消耗资源。
  LPC 会按 quest/id 反查玩家、显示位置，远端（西域/很远的地方）则传送回佛山。

  TODO(migrate): 引擎暂无玩家查找/传送原语，此处保留 gate 与运功文案，
  效果为 no-op（不改动任何状态）。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/xun",
      kind: :exert,
      gates: [
        {:custom, &gate_wiz_test/1, "你所学的内功中没有这种功能。\n"},
        {:custom, &gate_quest_id/1, "你所学的内功中没有这种功能。\n"}
      ],
      costs: %{},
      effects: [],
      busy: 0,
      message: fn ctx ->
        id = Map.get(ctx.character.meta.temp, :quest_id) || "目标"
        "$N运起寻踪秘术，凝神感知#{id}的所在方位。\n"
      end
    }
  end

  defp gate_wiz_test(ctx), do: Map.get(ctx.character.meta.temp, :wiz_test) == true

  defp gate_quest_id(ctx), do: Map.get(ctx.character.meta.temp, :quest_id) != nil
end