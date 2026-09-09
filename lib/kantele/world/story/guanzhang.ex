defmodule Kantele.World.Story.Guanzhang do
  @moduledoc "story:guanzhang 关羽与白虎赐元丹（LPC guanzhang.c）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
  alias Kantele.World.Story.Lines

  defp messages(), do: [
    "关羽：听说三弟你在长坂桥一下子吓跑了几十万大军，好厉害啊。",
    "张飞：那是自然，我吃了赐元丹，功力是更胜往昔！",
    "关羽：啧啧，真不错，三弟还有没有？",
    "张飞塞给关羽一颗白虎赐元丹，道：我这还多着呢。",
    "关羽：嘿嘿！",
    "张飞：噢！二哥，有件事忘说了，据说吃完以后人的脸色会变。",
    "关羽：怎么变？",
    "张飞：像我，白脸变黑脸呗，往相反的方向变嘛。",
    "关羽：靠！那我不是要变成绿脸了？",
    "张飞：应该。",
    "关羽狠狠的把赐元丹扔了出去。",
    {:action, fn ->
      case Gift.drop_to_random_room("gift/str2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
        :none -> nil
        {:ok, _player} -> "“啪”的一声一颗仙丹掉落到人间。"
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