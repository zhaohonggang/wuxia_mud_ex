defmodule Kantele.Character.CombatView do
  @moduledoc """
  战斗文案渲染（纯文本直出）
  """

  use Kalevala.Character.View

  def render("text", %{text: text}), do: text
end
