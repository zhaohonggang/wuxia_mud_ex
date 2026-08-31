defmodule Kantele.Character.CommandView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("prompt", %{character: character}) do
    %{vitals: vitals} = character.meta

    %EventText{
      topic: "Character.Prompt",
      data: vitals,
      text: [
        "[",
        ~i({hp}#{vitals.qi}/#{vitals.max_qi}气血{/hp} ),
        ~i({sp}#{vitals.jing}/#{vitals.max_jing}精{/sp} ),
        ~i({ep}#{vitals.neili}/#{vitals.max_neili}内力{/ep}),
        "] > "
      ]
    }
  end

  def render("unknown", _assigns) do
    "What?\n"
  end

  def render("text", %{text: text}) do
    text
  end

  def render("combat-text", %{text: text}) do
    text
  end

  def render("under-attack", %{name: name}) do
    ~i({color foreground="red"}看起来#{name}想杀死你！{/color}\n)
  end

  def render("kill-reward", %{exp: exp, potential: potential}) do
    ~i({color foreground="white"}你杀死了对手，获得 #{exp} 点实战经验、#{potential} 点潜能。{/color}\n)
  end

  def render("revive", _assigns) do
    "你慢慢睁开眼睛，发现自己躺在一个熟悉的地方，清醒了过来。\n"
  end
end
