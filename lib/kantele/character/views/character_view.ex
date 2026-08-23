defmodule Kantele.Character.CharacterView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.Event

  def render("name", %{character: character}) do
    ~i({character id="#{character.id}" name="#{character.name}" description="#{
      character.description
    }"}#{character.name}{/character})
  end

  def render("vitals", %{character: character}) do
    %Event{
      topic: "Character.Vitals",
      data: character.meta.vitals
    }
  end

  def render("not-found", %{name: name}) do
    ~i(这里没有 {color foreground="white"}#{name}{/color} 这个人。\n)
  end
end
