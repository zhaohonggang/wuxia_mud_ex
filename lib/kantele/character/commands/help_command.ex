defmodule Kantele.Character.HelpCommand do
  @moduledoc """
  帮助：`help|帮助 <主题>` 显示某个帮助主题、裸 `help|帮助` 列出全部主题

  主题按 key 或 keyword（关键词/中文别名）查找，都命中 `Kalevala.Help` 缓存。
  索引页从 `Kalevala.Help.Cache` 枚举全部已加载主题。主题内容较短（1-6 行），
  直接整页展示，无需 Kantele.Pager 分页（Pager 留给长文本宿主）。
  """

  use Kalevala.Character.Command

  alias Kalevala.Help
  alias Kantele.Character.HelpView

  def index(conn, _params) do
    topics =
      Help.Cache.keys()
      |> Enum.sort()
      |> Enum.map(fn key ->
        elem(Help.get(key), 1)
      end)

    render(conn, HelpView, "index", %{topics: topics})
  end

  def show(conn, %{"topic" => topic}) do
    case resolve_topic(topic) do
      {:ok, help_topic} ->
        conn
        |> assign(:help_topic, help_topic)
        |> render(HelpView, "show")

      :error ->
        conn
        |> assign(:topic, topic)
        |> render(HelpView, "unknown")
    end
  end

  # 先按 key 精确查，再按 keyword（含中文别名）查
  defp resolve_topic(topic) do
    case Help.get(topic) do
      {:ok, help_topic} ->
        {:ok, help_topic}

      {:error, :not_found} ->
        case Help.KeywordCache.get(topic) do
          {:ok, key} -> Help.get(key)
          {:error, :not_found} -> :error
        end
    end
  end
end
