defmodule Kantele.Character.MoveCommand do
  use Kalevala.Character.Command

  def north(conn, _params) do
    conn
    |> request_movement("north")
    |> assign(:prompt, false)
  end

  def south(conn, _params) do
    conn
    |> request_movement("south")
    |> assign(:prompt, false)
  end

  def east(conn, _params) do
    conn
    |> request_movement("east")
    |> assign(:prompt, false)
  end

  def west(conn, _params) do
    conn
    |> request_movement("west")
    |> assign(:prompt, false)
  end

  def up(conn, _params) do
    conn
    |> request_movement("up")
    |> assign(:prompt, false)
  end

  def down(conn, _params) do
    conn
    |> request_movement("down")
    |> assign(:prompt, false)
  end

  # 斜向/组合方向
  def northeast(conn, _params) do
    conn
    |> request_movement("northeast")
    |> assign(:prompt, false)
  end

  def northwest(conn, _params) do
    conn
    |> request_movement("northwest")
    |> assign(:prompt, false)
  end

  def southeast(conn, _params) do
    conn
    |> request_movement("southeast")
    |> assign(:prompt, false)
  end

  def southwest(conn, _params) do
    conn
    |> request_movement("southwest")
    |> assign(:prompt, false)
  end

  def northup(conn, _params) do
    conn
    |> request_movement("northup")
    |> assign(:prompt, false)
  end

  def southup(conn, _params) do
    conn
    |> request_movement("southup")
    |> assign(:prompt, false)
  end

  def eastup(conn, _params) do
    conn
    |> request_movement("eastup")
    |> assign(:prompt, false)
  end

  def westup(conn, _params) do
    conn
    |> request_movement("westup")
    |> assign(:prompt, false)
  end

  def northdown(conn, _params) do
    conn
    |> request_movement("northdown")
    |> assign(:prompt, false)
  end

  def southdown(conn, _params) do
    conn
    |> request_movement("southdown")
    |> assign(:prompt, false)
  end

  def eastdown(conn, _params) do
    conn
    |> request_movement("eastdown")
    |> assign(:prompt, false)
  end

  def westdown(conn, _params) do
    conn
    |> request_movement("westdown")
    |> assign(:prompt, false)
  end
end
