defmodule Kantele.Character.StudyCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.World.Item.Meta.Book

  describe "study 参数解析" do
    test "Book 结构包含必要字段" do
      book = %Book{
        skill: "liuxin-jian",
        min_skill: 0,
        max_skill: 100,
        exp_required: 1000,
        jing_cost: 5,
        difficulty: 10
      }

      assert book.skill == "liuxin-jian"
      assert book.min_skill == 0
      assert book.max_skill == 100
      assert book.exp_required == 1000
      assert book.jing_cost == 5
      assert book.difficulty == 10
    end
  end
end
