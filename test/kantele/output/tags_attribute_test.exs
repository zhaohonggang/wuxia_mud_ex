defmodule Kantele.Output.TagsAttributeTest do
  use ExUnit.Case, async: true

  alias Kalevala.Output
  alias Kalevala.Output.Tags

  describe "escape_attribute/1" do
    test "escapes quotes, braces and backslashes" do
      assert Tags.escape_attribute(~s(a"b{c}d\\e)) == ~s(a\\"b\\{c\\}d\\\\e)
    end

    test "leaves plain text untouched" do
      assert Tags.escape_attribute("一名普通的旅人。") == "一名普通的旅人。"
    end
  end

  describe "Kalevala.Output.process/2 with Tags" do
    test "unbalanced tags (raw quote in attribute) fall back to the raw string" do
      text = ~s(- {character id="c2" name="马夫" description="笑道："客官""}马夫{/character})

      assert Output.process(text, Tags) == [text]
    end

    test "escaped attribute values round-trip without falling back" do
      description = ~s(见人便笑道："客官想买坐骑？" {枪} \\ 混排)
      text = character_tag("马夫", description)

      result = Output.process(text, Tags)

      refute result == [text]

      assert {:open, "character", %{"name" => "马夫", "description" => ^description}} =
               Enum.find(result, &match?({:open, "character", _}, &1))
    end
  end

  defp character_tag(name, description) do
    ~s(- {character id="c1" name="#{Tags.escape_attribute(name)}" description="#{
      Tags.escape_attribute(description)
    }"}#{Tags.escape(name)}{/character})
  end
end
