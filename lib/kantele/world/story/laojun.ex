defmodule Kantele.World.Story.Laojun do
  @moduledoc "story:laojun 玉皇大帝求灵慧仙丹（LPC laojun.c）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
  alias Kantele.World.Story.Lines

  defp messages(), do: [
    "玉皇大帝：老君，你那儿有没有治笨病的药？",
    "太上老君：有，有，我这儿新研制了一种仙丹，可以使人变聪明。",
    "玉皇大帝大喜道：好，快给我两颗。",
    "太上老君疑惑道：莫非……",
    "玉皇大帝长叹一声：我们家那口子是越来越不行了，蟠桃园亏惨了！还不及弼马温管呢。",
    "太上老君掏出一葫芦：喏，这儿。",
    "玉皇大帝：哎呀！",
    "太上老君：不好，怎么掉了，马上派人去找找。",
    "玉皇大帝：算了算了，不就一颗丹嘛，再给我一颗就是了。",
    {:action, fn ->
      case Gift.drop_to_random_room("gift/int2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
        :none -> nil
        {:ok, _player} -> "听说天庭遗落了一枚仙丹。"
        {:error, _reason, _player} -> nil
      end
    end}
  ]

  @impl true
  def init_state(), do: %{}

  @impl true
  def prompt(), do: "{color foreground=\"green\"}【故事传闻】{/color}"

  @impl true
  def step(index, inner), do: Lines.step_lines(messages(), index, inner)
end