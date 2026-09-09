defmodule Kantele.World.Story.Feng do
  @moduledoc "story:feng 风灾——风伯过境，卷起漫天风沙（LPC feng.c，简化版）"
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
      "一阵狂风吹了起来，街边的纸鸢“呼”的一声便被卷上了半天。",
      "$N的衣服被吹得猎猎作响，几乎睁不开眼。",
      "狂风怒号，黄沙蔽日，风伯路过烟尘儿，卷起的风沙呼啸而出，街市上行人纷纷躲避。",
      "风声渐歇，风沙散去，天地复归清明。",
      "你低头一看，沙堆里居然埋着一样亮晶晶的东西。",
      {:action, fn ->
        if :rand.uniform(2) == 1 do
          case Gift.drop_to_room(inner[:room_id], "gift/dex2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
            :ok -> "风过处，遗下一枚仙丹，据说吃了身法如风。"
            _other -> nil
          end
        else
          "风伯打了个喷嚏，仙丹不知吹去了哪里。"
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end