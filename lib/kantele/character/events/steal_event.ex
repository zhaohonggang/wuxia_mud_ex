defmodule Kantele.Character.StealEvent do
  @moduledoc """
  偷窃结果事件处理：steal/result 由房间在偷窃判定完成后发送过来。
  目前房间直接处理了成功/失败消息，此处预留用于未来需要的客户端特效。
  """

  use Kalevala.Character.Event

  def result(conn, _params) do
    conn
  end
end
