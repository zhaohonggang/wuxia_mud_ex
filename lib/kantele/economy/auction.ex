defmodule Kantele.Economy.Auction do
  require Logger

  @moduledoc """
  拍卖行全局服务（对应 `adm/daemons/auctiond.c`）

  使用 ETS 存储全局拍卖品表，10 秒心跳驱动拍卖进度。
  4% 佣金（LPC lot_percent = 4/100）。

  ## 拍卖品状态
  - state: 1=刚挂出, 2=第1次提醒, 3=第2次提醒, 4=成交/流拍
  - time: 上次 state 变化的时间戳（秒）
  - value: 当前最高价
  - lot: 佣金 = value * 4 / 100
  """

  use GenServer

  @table :kantele_auctions
  @tick_interval 10_000
  @lot_percent 4

  @type auction_record :: %{
          character_id: String.t(),
          character_name: String.t(),
          goods_id: String.t(),
          goods_name: String.t(),
          goods_item_id: String.t(),
          value: integer(),
          lot: integer(),
          state: 1..4,
          time: integer(),
          now_bidder_id: String.t() | nil,
          now_bidder_name: String.t() | nil
        }

  # ---- GenServer API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "列出所有进行中的拍卖"
  def list_auctions, do: :ets.tab2list(@table)

  @doc "添加拍卖品（玩家对自己物品发起拍卖）"
  def add_auction(character, item_instance, price) when is_integer(price) and price > 0 do
    GenServer.call(__MODULE__, {:add, character, item_instance, price})
  end

  @doc "竞价（当前竞拍者出更高价）"
  def bid(auctioneer_id, bidder, price) when is_integer(price) and price > 0 do
    GenServer.call(__MODULE__, {:bid, auctioneer_id, bidder, price})
  end

  @doc "取消自己的拍卖"
  def cancel_auction(character_id) do
    GenServer.call(__MODULE__, {:cancel, character_id})
  end

  @doc "查询某玩家的拍卖品"
  def get_auction(character_id) do
    case :ets.lookup(@table, character_id) do
      [{^character_id, record}] -> {:ok, record}
      [] -> :error
    end
  end

  # ---- GenServer Implementation ----

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    schedule_tick()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:add, character, item_instance, price}, _from, state) do
    character_id = character.id

    if :ets.member(@table, character_id) do
      {:reply, {:error, :already_auctioning}, state}
    else
      lot = div(price * @lot_percent, 100)

      record = %{
        character_id: character_id,
        character_name: character.name,
        goods_id: item_instance.id,
        goods_name: item_instance.name || "物品",
        goods_item_id: item_instance.item_id,
        value: price,
        lot: lot,
        state: 1,
        time: System.system_time(:second),
        now_bidder_id: nil,
        now_bidder_name: nil
      }

      :ets.insert(@table, {character_id, record})
      broadcast_auction_message("#{character.name}开始拍卖#{record.goods_name}，底价#{price}文。")
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:bid, auctioneer_id, bidder, price}, _from, state) do
    case :ets.lookup(@table, auctioneer_id) do
      [{^auctioneer_id, record}] ->
        if price <= record.value do
          {:reply, {:error, :price_too_low}, state}
        else
          updated = %{
            record
            | value: price,
              lot: div(price * @lot_percent, 100),
              now_bidder_id: bidder.id,
              now_bidder_name: bidder.name,
              state: 1,
              time: System.system_time(:second)
          }

          :ets.insert(@table, {auctioneer_id, updated})
          broadcast_auction_message("#{bidder.name}对#{record.goods_name}出价#{price}文。")
          {:reply, :ok, state}
        end

      [] ->
        {:reply, {:error, :not_auctioning}, state}
    end
  end

  @impl true
  def handle_call({:cancel, character_id}, _from, state) do
    case :ets.lookup(@table, character_id) do
      [{^character_id, record}] ->
        :ets.delete(@table, character_id)
        broadcast_auction_message("#{record.character_name}取消了#{record.goods_name}的拍卖。")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_auctioning}, state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    tick()
    schedule_tick()
    {:noreply, state}
  end

  # ---- Internal ----

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp tick do
    now = System.system_time(:second)
    auctions = :ets.tab2list(@table)

    for {char_id, record} <- auctions do
      if now - record.time >= 10 do
        new_state = record.state + 1

        if new_state >= 4 do
          handle_settlement(char_id, record)
        else
          broadcast_auction_message(
            "#{record.goods_name}，#{money_str(record.value)}，第#{chinese_number(new_state - 1)}次。"
          )

          :ets.insert(@table, {char_id, %{record | state: new_state, time: now}})
        end
      end
    end
  end

  defp handle_settlement(char_id, record) do
    :ets.delete(@table, char_id)

    if record.now_bidder_id do
      broadcast_auction_message(
        "#{record.character_name}的#{record.goods_name}与#{record.now_bidder_name}成交#{
          money_str(record.value)
        }。"
      )
    else
      broadcast_auction_message("#{record.goods_name}无人竞价，流拍。")
    end
  end

  defp broadcast_auction_message(msg) do
    Kantele.Communication.announce("bill", msg)
  rescue
    _ ->
      Logger.info("[Auction] broadcast: #{msg}")
      :ok
  end

  defp money_str(n) when is_integer(n) do
    Kantele.Economy.Money.money_str(Kantele.Economy.Money.split(n))
  end

  defp chinese_number(n) when is_integer(n) do
    ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    |> Enum.at(n, Integer.to_string(n))
  end
end
