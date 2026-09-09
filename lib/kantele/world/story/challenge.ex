defmodule Kantele.World.Story.Challenge do
  @moduledoc "story:challenge 神秘挑战者摆擂（LPC challenge.c 真打版）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Challenger
  alias Kantele.World.Story.Lines

  @impl true
  def init_state(), do: %{}

  @impl true
  def prompt(), do: "{color foreground=\"red\"}【 挑  战 】{/color}"

  @impl true
  def step(index, inner) do
    lines = [
      "忽有一日，城中多了一位神秘的挑战者，自称踏遍中原罕见敌手，在各个道口摆下擂台。",
      "擂台之上，剑气纵横，围观的武林人士挤得水泄不通。",
      "一夜之间，接连三拨江湖好手败下阵来，台下鸦雀无声。",
      "那挑战者环视四围，抱拳朗声道：还有哪位英雄，愿与某家一试身手？",
      {:action, fn ->
        case Challenger.spawn_random() do
          {:ok, _challenger} -> "神秘挑战者当前就守在那里，等候天下英雄。"
          {:error, _reason} -> "擂台摆好了，却迟迟无人现身，围观众人渐渐散去。"
        end
      end},
      "围观的江湖人士有人心动，有人踌躇，不知谁愿第一个上台。",
      "据说只要键入 accept，便可应战。"
    ]

    Lines.step_lines(lines, index, inner)
  end
end