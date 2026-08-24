defmodule Kantele.Character.InfoView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("display", assigns) do
    %EventText{
      topic: "Character.Info",
      data: assigns,
      text: render("_display", assigns)
    }
  end

  def render("_display", assigns) do
    vitals = assigns.vitals

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
    {table}
      {row}
        {cell}膂力{/cell}
        {cell}#{assigns.str}{/cell}
        {cell}身法{/cell}
        {cell}#{assigns.dex}{/cell}
      {/row}
      {row}
        {cell}根骨{/cell}
        {cell}#{assigns.con}{/cell}
        {cell}悟性{/cell}
        {cell}#{assigns.int}{/cell}
      {/row}
      {row}
        {cell}实战经验{/cell}
        {cell}#{assigns.combat_exp}{/cell}
        {cell}潜能{/cell}
        {cell}#{assigns.potential}{/cell}
      {/row}
    {/table}
    """
  end
end
