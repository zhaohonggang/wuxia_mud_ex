defmodule Kantele.Character.FingerView do
  @moduledoc """
  finger 命令的展示（Batch 5）
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("list", %{characters: characters}) do
    %EventText{
      topic: "Character.Finger",
      text:
        "在线玩家：\n" <>
          (render("_characters", %{characters: characters}) <> "\n")
    }
  end

  def render("_characters", %{characters: characters}) do
    case Enum.map(characters, &("- " <> &1.name <> "\n")) do
      [] -> "（无）\n"
      lines -> Enum.join(lines)
    end
  end

  def render("player", %{character: character}) do
    %EventText{
      topic: "Character.Finger",
      text:
        "姓名：#{character.name}\n" <>
          "所在地：#{room_name(character)}\n"
    }
  end

  def render("not-found", %{name: name}) do
    %EventText{
      topic: "Character.Finger",
      text: "没有找到 #{name} 这个玩家。\n"
    }
  end

  defp room_name(character) do
    case Map.get(character, :room_id) do
      nil -> "未知"
      room_id -> "区域 #{room_id}"
    end
  end
end
