defmodule Kantele.Admin.Access do
  @moduledoc """
  Wizard access control module.

  Simulates LPC `wizardp()` and `valid_grant()` semantics.

  Wizard levels:
    0 - mortal player
    1 - wizard (wiz)
    2 - arch wizard (arch)
    3 - admin (adm)
  """

  @wiz_level 1
  @arch_level 2
  @admin_level 3

  def wiz_level, do: @wiz_level
  def arch_level, do: @arch_level
  def admin_level, do: @admin_level

  @doc """
  Returns true if the character is a wizard (wiz_level >= 1).
  Corresponds to LPC `wizardp()`.
  """
  def wizardp(%Kalevala.Character{} = character) do
    Map.get(character.attributes, "wiz_level", 0) >= @wiz_level
  end

  def wizardp(_), do: false

  @doc """
  Returns true if the character is an arch wizard (wiz_level >= 2).
  """
  def archwizp(%Kalevala.Character{} = character) do
    Map.get(character.attributes, "wiz_level", 0) >= @arch_level
  end

  def archwizp(_), do: false

  @doc """
  Returns true if the character is an admin (wiz_level >= 3).
  """
  def adminp(%Kalevala.Character{} = character) do
    Map.get(character.attributes, "wiz_level", 0) >= @admin_level
  end

  def adminp(_), do: false

  @doc """
  Check if granter can grant privileges to receiver.
  Granter must have strictly higher wiz_level than receiver.
  Corresponds to LPC `valid_grant()`.
  """
  def valid_grant(%Kalevala.Character{} = granter, %Kalevala.Character{} = receiver) do
    granter_level = Map.get(granter.attributes, "wiz_level", 0)
    receiver_level = Map.get(receiver.attributes, "wiz_level", 0)

    granter_level > receiver_level
  end

  def valid_grant(_, _), do: false

  @doc """
  Returns the wiz_level of a character, defaulting to 0.
  """
  def wiz_level(%Kalevala.Character{} = character) do
    Map.get(character.attributes, "wiz_level", 0)
  end

  def wiz_level(_), do: 0

  @doc """
  Check if character has at least the given wiz level.
  """
  def has_level?(%Kalevala.Character{} = character, level) when is_integer(level) do
    wiz_level(character) >= level
  end

  def has_level?(_, _), do: false
end
