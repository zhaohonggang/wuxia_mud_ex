defmodule Kantele.Character.LookCommand do
  use Kalevala.Character.Command

  # 带参 look <关键词>：查看房间墙上的牌子/菜单（item_desc）
  def run(conn, %{"target" => target}) when is_binary(target) and target != "" do
    conn
    |> event("room/item_desc", %{keyword: target})
    |> assign(:prompt, false)
  end

  def run(conn, _params) do
    conn
    |> event("room/look")
    |> assign(:prompt, false)
  end

  # 裸 look/l/watch/看：房间全景
  def run_bare(conn, _params) do
    conn
    |> event("room/look")
    |> assign(:prompt, false)
  end
end