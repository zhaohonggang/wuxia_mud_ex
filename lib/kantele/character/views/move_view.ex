defmodule Kantele.Character.MoveView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText
  alias Kantele.Character.CharacterView

  def render("enter", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} enters.)
  end

  def render("leave", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} leaves.)
  end

  def render("notice", %{character: character, direction: :to, reason: reason}) do
    %EventText{
      topic: "Room.CharacterEnter",
      data: %{character: character},
      text: [reason, "\n"]
    }
  end

  def render("notice", %{character: character, direction: :from, reason: reason}) do
    %EventText{
      topic: "Room.CharacterLeave",
      data: %{character: character},
      text: [reason, "\n"]
    }
  end

  def render("fail", %{reason: :no_exit, exit_name: exit_name}) do
    ~i(There is no exit #{exit_name}.\n)
  end

  # valid_leave 拦下时的正文：房间侧判定成立，但中止事件只能带 reason（原子），
  # 所以正文由这里按「房间 id + 方向」回查房间数据取 LPC notify_fail 原文。
  def render("fail", %{reason: reason, from: room_id, exit_name: exit_name}) do
    case Kantele.World.exit_veto_message(room_id, exit_name) do
      nil -> render("fail", %{reason: reason})
      msg -> msg
    end
  end

  def render("fail", %{reason: reason}) do
    _ = reason
    ~i()
  end
end
