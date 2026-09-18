defmodule Kantele.Combat.Skills.Force.Xun do
  @moduledoc """
  寻踪（对照 `kungfu/skill/force/xun.c`）

  仅限 wiz_test 权限且有 quest/id 的玩家；
  查找目标玩家并显示位置；若目标在西域/远地则传送到佛山。
  纯信息/传送指令，不消耗资源。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"xun" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/xun",
      kind: :exert,
      gates: [
        {:custom, &gate_wiz_test/1, "你所学的内功中没有这种功能。\n"},
        {:custom, &gate_quest_id/1, "你所学的内功中没有这种功能。\n"},
        {:custom, &gate_target_found/1, "没有找到这个人物。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_xun/1}
      ],
      busy: 0,
      message: fn ctx ->
        target = ctx.target
        where = ctx.target.meta.room
        "#{target.name}(#{target.id})现在在#{where.short}(#{where.id}).\n"
      end
    }
  end

  defp gate_wiz_test(ctx) do
    if ctx.character.meta.temp.wiz_test, do: :ok, else: {:error, "你所学的内功中没有这种功能。\n"}
  end

  defp gate_quest_id(ctx) do
    if ctx.character.meta.temp.quest_id, do: :ok, else: {:error, "你所学的内功中没有这种功能。\n"}
  end

  defp gate_target_found(ctx) do
    # In real impl would find player by ctx.character.meta.temp.quest_id
    if ctx.target, do: :ok, else: {:error, "没有找到这个人物。\n"}
  end

  defp effect_xun(state) do
    char = state.character
    target = state.target

    # Teleport if in far place
    if target.meta.place in ["西域", "很远的地方"] do
      target = %{target | meta: %{target.meta | room_id: "foshan/street3"}}
    end

    %{state | character: char, target: target}
  end
end
