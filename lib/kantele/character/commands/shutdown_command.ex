defmodule Kantele.Character.ShutdownCommand do
  use Kalevala.Character.Command

  def run(conn, _params), do: conn
end
