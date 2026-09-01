defmodule Kantele.World.AnalectaService do
  @moduledoc """
  文选守护进程：管理文章选集的存储、检索、添加、删除。

  对应 LPC ANALECTA_D 守护进程。
  """

  use GenServer

  import Ecto.Query

  alias Kantele.Repo
  alias Kantele.World.Analecta

  @doc "启动服务"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "获取某年度的文选列表"
  def query_analecta_list(year) do
    GenServer.call(__MODULE__, {:query_list, year})
  end

  @doc "添加文选"
  def add_analecta(year, analecta_data) do
    GenServer.call(__MODULE__, {:add, year, analecta_data})
  end

  @doc "删除文选"
  def delete_analecta(year, index) do
    GenServer.call(__MODULE__, {:delete, year, index})
  end

  @doc "获取某篇文选详情"
  def get_analecta(year, index) do
    GenServer.call(__MODULE__, {:get, year, index})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:query_list, year}, _from, state) do
    # 简单方案：获取所有后过滤（数据量小的情况下可接受）
    all_analectas = Repo.all(from a in Analecta,
      order_by: [desc: a.time],
      select: %{
        subject: a.subject,
        author_name: a.author_name,
        author_id: a.author_id,
        time: a.time,
        board: a.board,
        id: a.id,
        year: a.year
      }
    )

    filtered = Enum.filter(all_analectas, fn a -> a.year == year end)

    {:reply, filtered, state}
  end

  @impl true
  def handle_call({:add, year, analecta_data}, _from, state) do
    analecta = %Analecta{
      year: year,
      subject: analecta_data["subject"],
      author_name: analecta_data["author_name"],
      author_id: analecta_data["author_id"],
      content: analecta_data["content"],
      board: analecta_data["board"],
      time: analecta_data["time"],
      source_board: analecta_data["source_board"],
      source_note_index: analecta_data["source_note_index"]
    }

    case Repo.insert(analecta) do
      {:ok, _analecta} ->
        {:reply, :ok, state}
      {:error, changeset} ->
        {:reply, {:error, changeset.errors}, state}
    end
  end

  @impl true
  def handle_call({:delete, year, index}, _from, state) do
    analecta = Repo.get(Analecta, index)

    if analecta && analecta.year == year do
      case Repo.delete(analecta) do
        {:ok, _} -> {:reply, :ok, state}
        {:error, _} -> {:reply, {:error, "删除失败"}, state}
      end
    else
      {:reply, {:error, "没有这个年度的文选或该年度没有这个序号的文选"}, state}
    end
  end

  @impl true
  def handle_call({:get, year, index}, _from, state) do
    analecta = Repo.get(Analecta, index)

    if analecta && analecta.year == year do
      {:reply, {:ok, analecta}, state}
    else
      {:reply, {:error, "没有这个年度的文选或该年度没有这个序号的文选"}, state}
    end
  end
end