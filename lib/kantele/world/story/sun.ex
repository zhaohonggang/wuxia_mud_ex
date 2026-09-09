defmodule Kantele.World.Story.Sun do
  @moduledoc "story:sun 日灾——九日并出，火弹坠地（LPC sun.c，简化版）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
  alias Kantele.World.Story.Lines

  @impl true
  def init_state() do
    case Gift.random_player() do
      nil ->
        %{}

      player ->
        %{name: player.name, id: player.id, room_id: player.room_id}
    end
  end

  @impl true
  def prompt(), do: "{color foreground=\"red\"}【天灾人祸】{/color}"

  @impl true
  def step(index, inner) do
    lines = [
      "晴空万里，忽然间天上竟多出了九个太阳，烤得大地滋滋冒烟。",
      "$N抬头望去，只见一轮烈阳越滚越大，猛地朝头顶坠了下来！",
      "后羿弯弓搭箭，「嗖」的一声，射落其中一枚火弹，余火残光洒落人间。",
      "火光收歇，/$N脚边的焦土里，却透出一点温润的光。",
      "你俯身看去，竟是一颗被烈火淬炼过的丹药。",
      {:action, fn ->
        if :rand.uniform(2) == 1 do
          case Gift.drop_to_room(inner[:room_id], "gift/str2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
            :ok -> "烈阳余烬里，一颗淬火丹药滚到$N面前。"
            _other -> nil
          end
        else
          "那一点微光转眼便被热浪蒸干，什么都未曾留下。"
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end