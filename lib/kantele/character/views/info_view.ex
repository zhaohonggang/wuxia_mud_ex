defmodule Kantele.Character.InfoView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("display", %{character: character}) do
    %EventText{
      topic: "Character.Info",
      data: character,
      text: render("_display", %{character: character})
    }
  end

  def render("_display", %{character: character}) do
    vitals = character.meta.vitals

    ~i"""
    {table}
      {row}
        {cell}气 气血{/cell}
        {cell}{hp}#{vitals.qi}/#{vitals.max_qi}{/hp}{/cell}
      {/row}
      {row}
        {cell}精 精力{/cell}
        {cell}{sp}#{vitals.jing}/#{vitals.max_jing}{/sp}{/cell}
      {/row}
      {row}
        {cell}内力{/cell}
        {cell}{ep}#{vitals.neili}/#{vitals.max_neili}{/ep}{/cell}
      {/row}
    {/table}
    """
  end
end
