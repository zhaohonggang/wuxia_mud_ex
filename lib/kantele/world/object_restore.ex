defmodule Kantele.World.ObjectRestore do
  @moduledoc """
  restore 命令的持久层辅助（B2 W3 对象引擎二期预留接口）。

  LPC `restore` 依赖扁平文件备份系统（BACKUP_D / DUMP_DIR / TEMP_DIR / cp / rm），
  本端口玩家数据在 Postgres，无备份系统，故这里提供从数据库存档读取玩家记录的
  辅助，供 `Kantele.Character.RestoreCommand` 核验 / 恢复使用。

  真正把存档回写到运行态的逻辑在 `Kantele.Character.RestoreEvent`
  （目标进程自行 `Records.load` + `Records.apply_to_character`），避免跨进程改他人状态。
  """
  alias Kantele.Character.Records

  @doc """
  查询某个玩家的数据库存档信息。

  返回 `{:ok, %{name: binary, saved_at: DateTime.t() | nil}}` 或
  `{:error, :not_found}`（无角色记录或无元数据）。
  """
  def info(name) when is_binary(name) do
    case Records.load(name) do
      {:ok, metadata, _wiz_level} ->
        {:ok, %{name: name, saved_at: metadata.updated_at}}

      :error ->
        {:error, :not_found}
    end
  end
end
