defmodule Kantele.Character.ReloadView do
  use Kalevala.Character.View

  def render("recompiled", _assigns) do
    "Game code recompiled\n"
  end

  def render("reloaded", _assigns) do
    "Game world data reloaded!\n"
  end

  def render("reload_failed", assigns) do
    location =
      case assigns.file do
        nil ->
          ""

        file ->
          "（#{file}）"
      end

    "世界数据加载失败#{location}\n#{assigns.error}\n本次加载已放弃，旧世界继续运行，详情请查看服务端日志。\n"
  end
end
