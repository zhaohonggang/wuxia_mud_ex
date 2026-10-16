defmodule Kantele.Character.CharacterView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.Event

  def render("name", %{character: character}) do
    name_attribute = Kalevala.Output.Tags.escape_attribute(character.name)
    description = Kalevala.Output.Tags.escape_attribute(character.description)
    name = Kalevala.Output.Tags.escape(character.name)

    ~i({character id="#{character.id}" name="#{name_attribute}" description="#{description}"}#{
      name
    }{/character})
  end

  def render("vitals", %{character: character}) do
    %Event{
      topic: "Character.Vitals",
      data: character.meta.vitals
    }
  end

  def render("vitals", %{vitals: vitals}) do
    %Event{
      topic: "Character.Vitals",
      data: vitals
    }
  end

  def render("not-found", %{name: name}) do
    ~i(这里没有 {color foreground="white"}#{name}{/color} 这个人。\n)
  end
end
