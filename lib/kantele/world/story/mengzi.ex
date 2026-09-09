defmodule Kantele.World.Story.Mengzi do
  @moduledoc "story:mengzi 老者以拳脚换《孟子》（LPC mengzi.c）"
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
  def prompt(), do: "{color foreground=\"green\"}【故事传闻】{/color}"

  @impl true
  def step(index, inner) do
    # 玩家名会在播报时从 inner 提取 $N；未选中玩家时给兜底名
    lines =
      [
        "一名穿灰袍的老者缓缓走到$N面前，上上下下打量一番，忽然开口：这位侠士，老汉有本奇书相赠。",
        "$N一怔：老丈有何指教？",
        "老者捋着胡须：老汉生平最恨不识字之人，你若能把这本书读上一遍，老汉便将毕生所悟尽数传你。",
        "$N接过书，尚未翻开，书页间倏然涌出一道金光，直冲斗府。",
        {:action, fn ->
          case Gift.drop_to_room(inner[:room_id], "book/mengzi", "\n“啪”的一声，一本书掉到你面前。\n\n") do
            :ok -> "老者大笑道：孺子可教！这本书就送你了，望你日后人人头上有青天。"
            _other -> nil
          end
        end},
        "$N恍然四顾，那老者已不知何时不见了踪迹。"
      ]

    Lines.step_lines(lines, index, inner)
  end
end