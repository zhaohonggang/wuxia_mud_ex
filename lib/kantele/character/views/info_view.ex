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

  def render("_display", a) do
    v = a.vitals

    ~i"""
    {table}
      {row}
        {cell}气 气血{/cell}
        {cell}{hp}#{v.qi}/#{v.max_qi}{/hp}{/cell}
      {/row}
      {row}
        {cell}精 精力{/cell}
        {cell}{sp}#{v.jing}/#{v.max_jing}{/sp}{/cell}
      {/row}
      {row}
        {cell}内力{/cell}
        {cell}{ep}#{v.neili}/#{v.max_neili}{/ep}{/cell}
      {/row}
    {/table}
    {table}
      {row}
        {cell}膂力{/cell}
        {cell}#{a.str}{/cell}
        {cell}身法{/cell}
        {cell}#{a.dex}{/cell}
      {/row}
      {row}
        {cell}根骨{/cell}
        {cell}#{a.con}{/cell}
        {cell}悟性{/cell}
        {cell}#{a.int}{/cell}
      {/row}
      {row}
        {cell}实战经验{/cell}
        {cell}#{a.combat_exp}{/cell}
        {cell}潜能{/cell}
        {cell}#{a.potential}{/cell}
      {/row}
    {/table}
    {table}
      {row}
        {cell}基本内功{/cell}
        {cell}#{a.force_level}{/cell}
      {/row}
      {row}
        {cell}基本剑法{/cell}
        {cell}#{a.sword_level}{/cell}
      {/row}
      {row}
        {cell}轻功{/cell}
        {cell}#{a.dodge_level}{/cell}
      {/row}
      {row}
        {cell}招架{/cell}
        {cell}#{a.parry_level}{/cell}
      {/row}
      {row}
        {cell}基本拳脚{/cell}
        {cell}#{a.unarmed_level}{/cell}
      {/row}
    {/table}
    """
  end
end
