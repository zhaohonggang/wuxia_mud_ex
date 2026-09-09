defmodule Kantele.World.Story.Liandan do
  @moduledoc "story:liandan 孙悟空炼丹灶前飙丹（LPC liandan.c）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
  alias Kantele.World.Story.Lines

  defp messages(), do: [
    "孙悟空蹲在灶前忐忑不安地等着炼丹，炼丹的天兵都在偷偷打量他。",
    "孙悟空一脸苦恼地想：本来想做武功高手，不用苦练，只要吃太上老君的那葫芦丹药……结果是空欢喜一场。",
    "太上老君本欲给他颗丹补偿，见他一脸苦相，想了想就暂时放了他，让他安心烧火。",
    "九转丹成，开炉的一刻，孙悟空一个筋斗云，嗖的就冲了出去。",
    "太上老君：我的丹！我的丹！",
    "（一溜烟的功夫，孙悟空就从拐角处消失了。）",
    {:action, fn ->
      case Gift.drop_to_random_room("gift/dex2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
        :none -> nil
        {:ok, _player} -> "炼丹时飞蹦而出的一颗仙丹滴溜溜滚落到某处。"
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