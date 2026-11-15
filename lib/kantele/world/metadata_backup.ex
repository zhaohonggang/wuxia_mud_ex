defmodule Kantele.World.MetadataBackup do
  @moduledoc """
  游戏启动后执行一次性的 `character_metadata` 表备份，防止以后误删数据库。

  容器内未安装 `pg_dump`，改用 Ecto 查询全表并本地生成 SQL，
  写入 `/app/character_metadata_backup.sql`（bind mount 到宿主机
  `C:\files\git\wuxia_mud_ex\character_metadata_backup.sql`）。

  备份完成后自行停止，只在应用启动时运行一次。
  """

  use GenServer

  require Logger

  alias ExVenture.Characters.Metadata
  alias ExVenture.Repo

  @backup_path "/app/character_metadata_backup.sql"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{}, {:continue, :backup}}
  end

  @impl true
  def handle_continue(:backup, state) do
    try do
      rows = Repo.all(Metadata)
      sql = generate_backup_sql(rows)
      File.write!(@backup_path, sql)
      Logger.info("character_metadata backed up: #{length(rows)} rows -> #{@backup_path}")
    rescue
      e ->
        Logger.warn("character_metadata backup failed: #{Exception.message(e)}")
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp generate_backup_sql(rows) do
    header =
      "-- character_metadata backup (auto-generated on game start)\n" <>
      "-- Generated at: #{inspect(DateTime.utc_now())}\n\n"

    columns =
      [
        :id, :character_id, :str, :dex, :con, :int, :combat_exp, :potential,
        :learned_points, :max_neili, :max_jingli, :coins, :bank_coins, :score,
        :weiwang, :gongxian, :shen, :family, :gender, :skills, :mapped,
        :performs, :inventory, :equipment, :nickname, :title, :option,
        :alias_commands, :bag, :quest, :league, :brothers, :spouse, :schedule,
        :tianshu_books, :jifen, :marks, :env, :personality, :per, :kar,
        :setup_done, :inserted_at, :updated_at
      ]

    statements =
      Enum.map(rows, fn row ->
        values = Enum.map(columns, fn col -> sql_value(Map.get(row, col)) end)
        "INSERT INTO character_metadata (#{Enum.join(columns, ", ")}) VALUES (#{Enum.join(values, ", ")});\n"
      end)

    header <> Enum.join(statements, "\n") <> "\n"
  end

  defp sql_value(nil), do: "NULL"
  defp sql_value(value) when is_integer(value), do: Integer.to_string(value)
  defp sql_value(value) when is_boolean(value), do: if(value, do: "true", else: "false")
  defp sql_value(value) when is_binary(value), do: quote_string(value)
  defp sql_value(value) when is_struct(value) do
    if value.__struct__ == Ecto.DateTime do
      quote_string(Ecto.DateTime.to_iso8601(value))
    else
      quote_string(inspect(value))
    end
  end
  defp sql_value(value) when is_map(value) or is_list(value), do: quote_string(Jason.encode!(value))
  defp sql_value(value), do: quote_string(inspect(value))

  defp quote_string(s) do
    "'" <> String.replace(s, "'", "''") <> "'"
  end
end
