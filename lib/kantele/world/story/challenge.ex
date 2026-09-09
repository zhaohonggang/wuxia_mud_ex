defmodule Kantele.World.Story.Challenge do
  @moduledoc "story:challenge 神秘挑战者摆擂（LPC challenge.c，叙事简化版）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
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
      "据说话音未落，已有一位少年纵身跃上擂台，引得满场惊呼。",
      {:action, fn ->
        if :rand.uniform(2) == 1 do
          case Gift.drop_to_random_room(
                 "misc/xuantie-ling",
                 "\n“啪”的一声，一枚玄铁令掉到你面前。\n\n"
               ) do
            {:ok, _player} ->
              "那挑战者被击退半步，抱拳一笑：好身手！某家甘拜下风，这枚玄铁令奉上。"
            _other -> nil
          end
        else
          "双方你来我往各亮绝招，最终并肩而立，双双罢手，各饮一碗烈酒，纵声长笑。"
        end
      end},
      "次日清晨，擂台兀自还在，那神秘的挑战者却已不知去向。"
    ]

    Lines.step_lines(lines, index, inner)
  end
end