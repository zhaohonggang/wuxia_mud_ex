defmodule Kantele.World.Story.Bizhen do
  @moduledoc "story:bizhen 吴道通的烧饼与玄铁令（LPC bizhen.c，简化版）"
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
      "摩天崖下的小镇上出了桩奇事，卖烧饼的吴道通手里忽然多了一块黑黝黝的铁片。",
      "吴道通害了怕，把那唤作玄铁令的铁片塞进烧饼肚子里，谁承想正撞上$N经过。",
      "只见那烧饼“噗”地一声从担子上滚落，正好落在$N脚边。",
      "$N俯身拾起，那烧饼硬邦邦的，掰开一看，竟藏着一枚乌沉沉的铁令。",
      "四周寻视，那吴道通早已跌跌撞撞躲进人群，不见了踪影。",
      {:action, fn ->
        case Gift.drop_to_room(inner[:room_id], "misc/xuantie-ling", "\n“啪”的一声，一枚玄铁令掉到你面前。\n\n") do
          :ok -> "据说那玄铁令可号令摩天居士谢烟客，江湖中人听闻，无不动容。"
          _other -> nil
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end