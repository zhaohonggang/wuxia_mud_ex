defmodule Kantele.World.NewsService do
  @moduledoc """
  新闻守护进程：管理游戏新闻的发布、阅读、搜索、删除。

  对应 LPC NEWS_D 守护进程。
  """

  use GenServer

  import Ecto.Query

  alias Kantele.Repo
  alias Kantele.World.News

  @doc "启动服务"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "显示新闻列表"
  def show_news(show_all) do
    GenServer.call(__MODULE__, {:show_news, show_all})
  end

  @doc "阅读指定新闻"
  def read_news(id) do
    GenServer.call(__MODULE__, {:read, id})
  end

  @doc "发布新闻"
  def do_post(author_name, author_id, title, content) do
    GenServer.call(__MODULE__, {:post, author_name, author_id, title, content})
  end

  @doc "删除新闻"
  def do_discard(author_id, id) do
    GenServer.call(__MODULE__, {:discard, author_id, id})
  end

  @doc "搜索新闻"
  def do_search(field, keyword) do
    GenServer.call(__MODULE__, {:search, field, keyword})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:show_news, show_all}, _from, state) do
    query = from n in News, order_by: [desc: n.time]

    if !show_all do
      # 只显示最新10条
      query = limit(query, 10)
    end

    news_list = Repo.all(query)

    {:reply, news_list, state}
  end

  @impl true
  def handle_call({:read, id}, _from, state) do
    news = Repo.get(News, id)

    if news do
      {:reply, {:ok, news}, state}
    else
      {:reply, {:error, "没有这条新闻"}, state}
    end
  end

  @impl true
  def handle_call({:post, author_name, author_id, title, content}, _from, state) do
    news = %News{
      title: title,
      author_name: author_name,
      author_id: author_id,
      content: content,
      time: :os.system_time(:second),
      category: "general"
    }

    case Repo.insert(news) do
      {:ok, news} ->
        {:reply, {:ok, news.id}, state}
      {:error, changeset} ->
        {:reply, {:error, changeset.errors}, state}
    end
  end

  @impl true
  def handle_call({:discard, author_id, id}, _from, state) do
    news = Repo.get(News, id)

    if news && news.author_id == author_id do
      case Repo.delete(news) do
        {:ok, _} -> {:reply, :ok, state}
        {:error, _} -> {:reply, {:error, "删除失败"}, state}
      end
    else
      {:reply, {:error, "没有这条新闻或你无权删除"}, state}
    end
  end

  @impl true
  def handle_call({:search, field, keyword}, _from, state) do
    pattern = "%#{keyword}%"
    results = case field do
      "title" ->
        Repo.all(from n in News, where: like(n.title, ^pattern), order_by: [desc: n.time])
      "author" ->
        Repo.all(from n in News, where: like(n.author_name, ^pattern), order_by: [desc: n.time])
      "document" ->
        Repo.all(from n in News, where: like(n.content, ^pattern), order_by: [desc: n.time])
      _ ->
        []
    end

    {:reply, results, state}
  end
end