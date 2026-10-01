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

  # 特殊方向
  def enter(conn, _params) do
    conn
    |> request_movement("enter")
    |> assign(:prompt, false)
  end

  def out(conn, _params) do
    conn
    |> request_movement("out")
    |> assign(:prompt, false)
  end

  def go_in(conn, _params) do
    conn
    |> request_movement("in")
    |> assign(:prompt, false)
  end

  def climb(conn, _params) do
    conn
    |> request_movement("climb")
    |> assign(:prompt, false)
  end

  # ---- 自定义方向名 ----
  #
  # LPC 允许任意字符串做方向名，语料里除标准 22 个之外还有 7 个真实在用：
  #   leitai  city/wudao1~4      擂台（4 个房间）
  #   river   guanwai/heimuya 19 处  渡船
  #   dule / caihong / panlong  room/xiaoyuan  建房系统三个子区
  #   yangzhou test/global 靶场出口
  # 之前这些方向在房间里能看到、却打不出来（命令路由报 "What?"），
  # 因为 move_command.ex 只为固定方向定义了函数。
  #
  # `liuxi` 由 Kantele.Character.LiuxiCommand 持有（它同时认 `柳溪` 这个中文
  # 别名，且出自 LPC cmds/std/liuxi.c），那边同样是 request_movement("liuxi")。
  def leitai(conn, _params) do
    conn
    |> request_movement("leitai")
    |> assign(:prompt, false)
  end

  def river(conn, _params) do
    conn
    |> request_movement("river")
    |> assign(:prompt, false)
  end

  def dule(conn, _params) do
    conn
    |> request_movement("dule")
    |> assign(:prompt, false)
  end

  def caihong(conn, _params) do
    conn
    |> request_movement("caihong")
    |> assign(:prompt, false)
  end

  def panlong(conn, _params) do
    conn
    |> request_movement("panlong")
    |> assign(:prompt, false)
  end

  def yangzhou(conn, _params) do
    conn
    |> request_movement("yangzhou")
    |> assign(:prompt, false)
  end
end
