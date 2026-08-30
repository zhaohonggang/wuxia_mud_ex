defmodule Kantele.Item.TypeTest do
  use ExUnit.Case, async: true

  alias Kantele.Item

  describe "type/1" do
    test "weapon" do
      assert Item.type(%{"is_weapon" => true}) == "武器"
    end

    test "armor" do
      assert Item.type(%{"is_armor" => true}) == "防具"
    end

    test "food" do
      assert Item.type(%{"is_food" => true}) == "食物"
    end

    test "liquid" do
      assert Item.type(%{"is_liquid" => true}) == "饮具"
    end

    test "container" do
      assert Item.type(%{"is_container" => true}) == "容器"
    end

    test "book" do
      assert Item.type(%{"is_book" => true}) == "书物"
    end

    test "money" do
      assert Item.type(%{"is_money" => true}) == "货币"
    end

    test "charm" do
      assert Item.type(%{"is_charm" => true}) == "护身符"
    end

    test "rune" do
      assert Item.type(%{"is_rune" => true}) == "符文"
    end

    test "inlaid" do
      assert Item.type(%{"is_inlaid" => true}) == "镶嵌物"
    end

    test "task" do
      assert Item.type(%{"is_task" => true}) == "任务物品"
    end

    test "default misc" do
      assert Item.type(%{}) == "杂物"
      assert Item.type(%{"foo" => "bar"}) == "杂物"
    end

    test "first match wins" do
      meta = %{"is_weapon" => true, "is_armor" => true}
      assert Item.type(meta) == "武器"
    end
  end
end
