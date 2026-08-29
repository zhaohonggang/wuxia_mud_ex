defmodule Kantele.Character.HelpView do
  use Kalevala.Character.View

  def render("index", %{topics: topics}) do
    ["可用帮助主题：\n"] ++
      Enum.map(topics, fn topic -> render("_entry", %{topic: topic}) end)
  end

  def render("_entry", %{topic: %{key: key, title: title, tagline: tagline}}) do
    padding = String.pad_trailing(key, 12)

    line = ~i(  {color foreground="white"}#{padding}{/color} #{title})

    case tagline do
      tag when is_binary(tag) and tag != "" ->
        [line, ~i(（#{tag}）), "\n"]

      _ ->
        [line, "\n"]
    end
  end

  def render("show", %{help_topic: help_topic}) do
    [
      ~i(Topic: {color foreground="white"}#{help_topic.title}{/color}\n),
      render("_keywords", %{keywords: help_topic.keywords}),
      render("_see_also", %{see_also: help_topic.see_also}),
      ~i(#{help_topic.content}\n)
    ]
  end

  def render("_keywords", %{keywords: []}), do: ""

  def render("_keywords", %{keywords: keywords}) do
    keywords =
      keywords
      |> Enum.map(fn keyword ->
        ~i({color foreground="white"}#{keyword}{/color})
      end)
      |> Enum.intersperse(", ")

    ~i(Keywords: #{keywords}\n)
  end

  def render("_see_also", %{see_also: []}), do: ""

  def render("_see_also", %{see_also: see_also}) do
    see_also =
      see_also
      |> Enum.map(fn keyword ->
        ~i({color foreground="white"}#{keyword}{/color})
      end)
      |> Enum.intersperse(", ")

    ~i(See also: #{see_also}\n)
  end

  def render("unknown", %{topic: topic}) do
    ~i(Unknown topic {color foreground="white"}#{topic}{/color}.\n)
  end
end
