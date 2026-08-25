defmodule Kantele.Character.WorldStatusCommand do
  @moduledoc """
  查询上一次世界加载的结果（时间/成功与否/原因/出错文件）

  供管理员排查热更失败使用；世界从未加载过时也会明确提示。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.WorldStatusView
  alias Kantele.World.Kickoff

  def run(conn, _params) do
    render(conn, WorldStatusView, "display", %{last_load: Kickoff.status()})
  end
end
