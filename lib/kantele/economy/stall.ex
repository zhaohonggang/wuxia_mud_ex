defmodule Kantele.Economy.Stall do
  @moduledoc """
  摆摊服务（对应 LPC cmds/usr/baitan.c）

  玩家通过 baitan 命令开启摊位，通过 stock/unstock 管理上架货物。
  摊位状态存于 ETS（`:kantele_stalls`，key = character_id）。

  ## 限制条件（LPC 移植）
  - 需 `is_vendor` 标志（商会成员）
  - 战斗中不可摆摊
  - 有 killer 状态不可摆摊
  - 特定区域（no_trade/no_fight）不可摆摊
  """

  use GenServer

  require Logger

  @table :kantele_stalls

  @type stall_record :: %{
          character_id: String.t(),
          character_name: String.t(),
          room_id: String.t(),
          goods: [
            %{
              item_instance_id: String.t(),
              item_id: String.t(),
              name: String.t(),
              price: integer()
            }
          ],
          started_at: integer()
        }

  # ---- GenServer API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list_stalls, do: :ets.tab2list(@table)

  def get_stall(character_id) do
    case :ets.lookup(@table, character_id) do
      [{^character_id, record}] -> {:ok, record}
      [] -> :error
    end
  end

  def start_stall(character, room_id) do
    GenServer.call(__MODULE__, {:start, character, room_id})
  end

  def stop_stall(character_id) do
    GenServer.call(__MODULE__, {:stop, character_id})
  end

  def stock_item(character_id, item_instance, price) do
    GenServer.call(__MODULE__, {:stock, character_id, item_instance, price})
  end

  def unstock_item(character_id, item_instance_id) do
    GenServer.call(__MODULE__, {:unstock, character_id, item_instance_id})
  end

  def list_goods(character_id) do
    case get_stall(character_id) do
      {:ok, record} -> record.goods
      :error -> []
    end
  end

  # ---- GenServer Implementation ----

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:start, character, room_id}, _from, state) do
    character_id = character.id

    if :ets.member(@table, character_id) do
      {:reply, {:error, :already_stalling}, state}
    else
      record = %{
        character_id: character_id,
        character_name: character.name,
        room_id: room_id,
        goods: [],
        started_at: System.system_time(:second)
      }

      :ets.insert(@table, {character_id, record})
      Logger.info("[Stall] #{character.name} started a stall in room #{room_id}")
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:stop, character_id}, _from, state) do
    case :ets.lookup(@table, character_id) do
      [{^character_id, _record}] ->
        :ets.delete(@table, character_id)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_stalling}, state}
    end
  end

  @impl true
  def handle_call({:stock, character_id, item_instance, price}, _from, state) do
    case :ets.lookup(@table, character_id) do
      [{^character_id, record}] ->
        goods_entry = %{
          item_instance_id: item_instance.id,
          item_id: item_instance.item_id,
          name: item_instance_name(item_instance),
          price: price
        }

        updated = %{record | goods: record.goods ++ [goods_entry]}
        :ets.insert(@table, {character_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_stalling}, state}
    end
  end

  @impl true
  def handle_call({:unstock, character_id, item_instance_id}, _from, state) do
    case :ets.lookup(@table, character_id) do
      [{^character_id, record}] ->
        updated = %{
          record
          | goods: Enum.reject(record.goods, &(&1.item_instance_id == item_instance_id))
        }

        :ets.insert(@table, {character_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_stalling}, state}
    end
  end

  defp item_instance_name(inst) do
    case Kantele.World.Items.get(inst.item_id) do
      {:ok, item} -> item.name
      _ -> inst.item_id || "物品"
    end
  end
end
