defmodule Kantele.World.Story.Water do
  @moduledoc "story:water 水灾——黄河决口，河伯遣书（LPC water.c，简化版）"
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
      "黄河忽然间怒吼起来，浊浪滔天，转眼间便淹了半条官道。",
      "$N避之不及，一个浪头卷来，人已被推了个趔趄，满身泥水。",
      "浪涛之中，影影绰绰浮着一物，随波逐流到了$N脚边。",
      "你定睛一看，竟是一颗被河水浸得透亮的仙丹。",
      {:action, fn ->
        if :rand.uniform(2) == 1 do
          case Gift.drop_to_room(inner[:room_id], "gift/int2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
            :ok -> "河伯摸了摸胡子，把这颗灵慧仙丹送到$N面前。"
            _other -> nil
          end
        else
          "浊浪一卷，那点光亮转眼便沉入河底，再无踪迹。"
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end