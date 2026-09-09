defmodule Kantele.World.Story.Sanfenjian do
  @moduledoc "story:sanfenjian 红花会三分剑术（LPC sanfenjian.c，简化版）"
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
  def prompt(), do: "{color foreground=\"green\"}【武林传闻】{/color}"

  @impl true
  def step(index, inner) do
    lines = [
      "红花会总舵主余鱼同与骆冰虽是结义兄妹，对剑招却从不藏私。",
      "这一夜，二人在西湖柳浪闻莺处演剑，剑光如水，将一湖月色都涤得清亮。",
      "骆冰笑着点住余鱼同的剑锋：这一招叫三分，可以传人，你得记住了。",
      "$N恰在湖畔画舫中听得真切，那三分剑术的要诀一字一句落入耳中。",
      "传闻自此，红花会的三分剑术便有了流传出来的源头，江湖上人人向往。",
      {:action, fn ->
        case Gift.drop_to_room(inner[:room_id], "gift/str2", "\n“啪”的一声，一枚仙丹落到你面前。\n\n") do
          :ok -> "据说练成三分剑术的弟子，逢敌不过三剑。"
          _other -> nil
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end