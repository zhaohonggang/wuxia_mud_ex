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

  # 守卫拦下时的正文。守卫的拒绝语来自 Guarder.permit_pass/1（LPC
  # F_GUARDER 的 message_vision 文案），房间里没有副本，所以由 room.ex
  # 连同 reason 一起带过来 —— 不能走下面 exit_veto_message 的回查路径。
  #
  # 这个子句必须排在 %{reason: reason, from: ..., exit_name: ...} 之前，
  # 否则会被那条更通用的子句先匹配掉。
  # 陷阱拦下时的正文。同 guarder：正文由房间进程随 reason 带过来
  #（陷阱的判定结果本来就只在房间里算得出来）。
  # 同样必须排在 %{reason:, from:, exit_name:} 那条通用子句之前。
  def render("fail", %{reason: {:trapped, msg}}) when is_binary(msg) do
    msg
  end

  def render("fail", %{reason: {:guarder_denied, msg}}) when is_binary(msg) do
    render_guarder_msg(msg)
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

  # guarder.msgs 里可以写 {npc} / {name} 占位（见 data/world/global.ucl 的
  # 白驼山庄门卫）。这里做一次朴素替换；未知占位原样保留。
  defp render_guarder_msg(msg) do
    Enum.reduce([{"{npc}", "守门人"}, {"{name}", "你"}], msg, fn {k, v}, acc ->
      String.replace(acc, k, v)
    end)
  end
end
