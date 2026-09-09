defmodule Kantele.World.Story.Lighting do
  @moduledoc "story:lighting 雷灾——九天玄雷劈下（LPC lighting.c，简化版）"
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
      "本来好好的天，忽然间紫电横空，一连串巨雷在头顶炸响。",
      "$N只觉得天旋地转，一道闪电直直劈向身前三步之处！",
      "雷光过处，焦黑的地上竟嵌着一块其貌不扬的石头，隐隐有雷纹流转。",
      "你走近细看，那分明是一颗被雷洗练过的丹药。",
      {:action, fn ->
        if :rand.uniform(2) == 1 do
          case Gift.drop_to_room(inner[:room_id], "gift/con2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
            :ok -> "雷神打了个响鼻，留下这颗铸骨丹，霜落人间。"
            _other -> nil
          end
        else
          "雷光一散，地上空空如也，仿佛方才只是一场幻梦。"
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end