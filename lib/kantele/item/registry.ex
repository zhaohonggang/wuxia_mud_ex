defmodule Kantele.Item.Registry do
  @moduledoc """
  唯一物品注册表（对应 LPC 真武剑/任务物品的唯一性追踪）

  - 每个唯一物品仅存在一个实例（或标记唯一）
  - 支持 `locate/1`（当前持有者/房间）、`transfer/2`（转移）、`destroy_unique/1`（销毁/重置）
  - 持久化到数据库（Ecto schema `unique_items`），重启可恢复
  """

  alias Kantele.Repo
  alias Kantele.Item.Registry.UniqueItem

  @type item_id :: String.t()
  @type holder :: %{type: :player | :room | :npc, id: String.t(), pid: pid() | nil}

  @doc "注册一件唯一物品（启动时调用，幂等）"
  def register(item_id, item_template_id, holder) do
    case Repo.get_by(UniqueItem, item_id: item_id) do
      nil ->
        %UniqueItem{
          item_id: item_id,
          item_template_id: item_template_id,
          holder_type: holder.type,
          holder_id: holder.id,
          holder_pid: holder.pid
        }
        |> Repo.insert!()

      existing ->
        # 已存在则更新持有者
        Repo.update!(%{existing |
          holder_type: holder.type,
          holder_id: holder.id,
          holder_pid: holder.pid
        })
    end
  end

  @doc "查询唯一物品当前持有者"
  def locate(item_id) do
    case Repo.get_by(UniqueItem, item_id: item_id) do
      nil -> nil
      item -> holder_of(item)
    end
  end

  @doc "转移唯一物品给新持有者"
  def transfer(item_id, new_holder) do
    case Repo.get_by(UniqueItem, item_id: item_id) do
      nil -> {:error, :not_found}
      item ->
        Repo.update!(%{item |
          holder_type: new_holder.type,
          holder_id: new_holder.id,
          holder_pid: new_holder.pid
        })
        {:ok, holder_of(item)}
    end
  end

  @doc "销毁/重置唯一物品（任务完成/巫师清理）"
  def destroy_unique(item_id) do
    case Repo.get_by(UniqueItem, item_id: item_id) do
      nil -> :ok
      item -> Repo.delete!(item)
    end
  end

  @doc "列出所有唯一物品（巫师面板用）"
  def all() do
    Repo.all(UniqueItem)
    |> Enum.map(&holder_of/1)
  end

  defp holder_of(%UniqueItem{} = item) do
    %{
      item_id: item.item_id,
      item_template_id: item.item_template_id,
      holder: %{
        type: item.holder_type,
        id: item.holder_id,
        pid: item.holder_pid
      }
    }
  end
end