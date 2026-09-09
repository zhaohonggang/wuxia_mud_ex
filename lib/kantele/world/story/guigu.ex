defmodule Kantele.World.Story.Guigu do
  @moduledoc "story:guigu 千年前枯骨旁的头骨与《鬼谷神算》（LPC guigu.c）"
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
  def prompt(), do: "{color foreground=\"white\"}【悠悠传奇】{/color}"

  @impl true
  def step(index, inner) do
    lines = [
      "是谁留下这本宋朝的《鬼谷子》呢？也就是后来的《鬼谷神算》，传说千年前埋在这枯骨之旁。",
      "故事还要从《鬼谷神算》说起……却道是一片迷离的往事。",
      "《鬼谷神算》云集了历代高僧大德毕生的心血，这本书原名顶佛，後世好事者改名鬼谷，讹传开来。",
      "寂寞天星之道，幽幽千古，几多禁令皆在这本书间化作泡影。",
      "据说得到此书的$N，只要潜心诵读，便可窥见天机，占卜算命样样精通。",
      "据说此书经百年沧海桑田、群雄冶炼，方成为如今这本通体清光流转的奇书。",
      {:action, fn ->
        case Gift.drop_to_room(inner[:room_id], "book/guigu", "\n“啪”的一声，一本古书掉到你面前。\n\n") do
          :ok -> "那一夜无星无月，枯骨之旁多了一本书，遥对九霄。"
          _other -> nil
        end
      end},
      "所谓世外高人，大约就是这般，把奇书随手赠人，飘然而去。"
    ]

    Lines.step_lines(lines, index, inner)
  end
end