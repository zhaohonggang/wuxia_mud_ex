defmodule ExKantele.World.Room.BasePigRoom do
  require Bitwise
  @moduledoc """
  对应原文件: lpc_example/inherit/inherit_room_pigroom.c (拱猪房, 20901B)
  迁移判定: C —— 房间级卡牌(拱猪/Gong Zhu)状态机，强依赖 PIG_D 守护进程。
  PIG_D 与 pig.h 不在本仓库；本模块移植**自包含**的房间状态机与校验逻辑，
  并把 PIG_D 必需的能力面记为框架依赖（见 FRAMEWORK_REQUIREMENTS.md）。

  状态机阶段:
    :initting -> :dealing -> :bidding -> :playing

  牌模型（假定守护方遵循）:
    牌号 0..51；suit = c div 13；rank = c rem 13
    花: 0=黑桃♠ 1=红桃♥ 2=方块♦ 3=梅花♣
    座位: 'north / 'west / 'south / 'east
  """

  @seats ["north", "west", "south", "east"]

  @phases [:initting, :dealing, :bidding, :playing]

  @chinese_seat %{
    "north" => "北边",
    "west" => "西边",
    "south" => "南边",
    "east" => "东边"
  }

  @doc "牌 -> 花色"
  def suit(card), do: div(card, 13)

  @doc "初始 52 张牌 (0..51) 与四人手牌 (13/人) 结构"
  def new_deck, do: Enum.to_list(0..51)

  def init_hands, do: %{"north" => [], "west" => [], "south" => [], "east" => []}

  @doc "发牌：把洗好的 newcards 依次发给四个座位，再各自排序"
  def deal(newcards) do
    hands =
      @seats
      |> Enum.with_index()
      |> Map.new(fn {seat, s} ->
        {seat, newcards |> Enum.with_index() |> Enum.filter(fn {_, i} -> rem(i, 4) == s end) |> Enum.map(&elem(&1, 0))}
      end)

    Map.new(hands, fn {seat, cards} -> {seat, Enum.sort(cards)} end)
  end

  # ==================== table_str 显示 ====================

  @doc """
  table_str：把当前牌桌状态格式化为面向某人(dirs)的文本。
  state: %{phase, round_no, roundcards, roundcard_count, round_order,
            cards, card_count, bidcard_str, pl}
  """
  def table_str(state, _dir \\ "north") do
    phase = state.phase

    if phase == :playing and pl_count(state) == 4 do
      order = state.round_order
      rc = state.roundcards

      intro =
        if state.roundcard_count < 4 do
          now = Enum.at(order, state.roundcard_count)
          "现在是第#{state.round_no}轮，该由#{name_of(state, now)}出牌。"
        else
          ""
        end

      sold =
        if state.bidcard_str == "" do
          "没有人卖牌。"
        else
          "卖了的牌：" <> state.bidcard_str
        end

      Enum.join(
        [
          intro,
          sold,
          "      （" <> name_of(state, Enum.at(order, 2)) <> "）",
          card_text(rc, Enum.at(order, 2)),
          card_row(state, order),
          card_text(rc, Enum.at(order, 0)),
          "      （" <> name_of(state, Enum.at(order, 0)) <> "）"
        ],
        "\n"
      )
    else
      status = Enum.reduce(@seats, "", fn seat, acc ->
        cond do
          not Map.has_key?(state.pl, seat) ->
            acc <> "#{@chinese_seat[seat]}的椅子是空的。 想玩可用 sit #{seat} 坐上去。\n"

          Map.get(state.pl, seat) == state.server ->
            acc <> "#{@chinese_seat[seat]}的椅子上坐的是：#{name_of(state, seat)}(桌长)。\n"

          true ->
            acc <> "#{@chinese_seat[seat]}的椅子上坐的是：#{name_of(state, seat)}。\n"
        end
      end)

      "这是一张专门用于拱猪的四方桌。\n" <> status
    end
  end

  defp card_row(state, order) do
    l = name_of(state, Enum.at(order, 3))
    r = name_of(state, Enum.at(order, 1))
    c3 = card_text(state.roundcards, Enum.at(order, 3))
    c1 = card_text(state.roundcards, Enum.at(order, 1))
    "    #{"（" <> l <> "）"}        #{c3}        #{c1} #{"（" <> r <> "）"}"
  end

  defp card_text(roundcards, dir), do: Map.get(roundcards, dir, "-")

  def name_of(state, dir) when is_binary(dir) do
    case Map.get(state.pl, dir) do
      nil -> @chinese_seat[dir]
      name when is_binary(name) -> name
      _ -> @chinese_seat[dir]
    end
  end

  @doc "scoreboard_str：成绩表"
  def scoreboard_str(scores) do
    rows =
      @seats
      |> Enum.map(fn seat ->
        case Map.get(scores, seat) do
          %{name: name, hscore: h, tscore: t} ->
            String.pad_trailing(name, 14) <> String.pad_leading("#{h}", 10) <> String.pad_leading("#{t}", 10)

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    Enum.join(rows, "\n")
  end

  @doc "pl_count：在场人数"
  def pl_count(state), do: state.pl |> Map.keys() |> length()

  # ==================== do_play 校验（自包含部分） ====================

  @doc """
  valid_play?：判断 dir 能否出 card。
    - 是否在场/阶段是否正确/是否轮到他
    - 手里是否有该牌
    - 是否需跟花（首轮花色）
    - 卖过的牌不能在首轮出
  state 需含: phase, round_order, roundcard_count, cards, card_count,
              roundcards, allow_playbid
  Returns :ok | {:error, msg}
  """
  def valid_play?(state, dir, card) do
    cond do
      not Map.has_key?(state.pl, dir) ->
        {:error, "你没有在拱猪！"}

      state.phase != :playing ->
        {:error, "现在不是出牌阶段！"}

      Enum.at(state.round_order, state.roundcard_count) != dir ->
        {:error, "还没轮到你出牌！"}

      card < 0 or card > 51 ->
        {:error, "你要出哪张牌？"}

      not Enum.member?(state.cards[dir], card) ->
        {:error, "你手里没有这张牌！"}

      true ->
        cond do
          # 跟花：首轮花色已定且手上有同花
          state.roundcard_count > 0 and
              following_lead_suit?(state, dir, card) ->
            {:error, "你不能出这张牌！"}

          # 卖过的牌不能在首轮出
          state.roundcard_count == 0 and following_card_sold?(state, dir, card) ->
            {:error, "卖过的牌不能在第一轮出！"}

          true ->
            :ok
        end
    end
  end

  defp following_lead_suit?(state, dir, card) do
    lead_suit = suit(Map.get(state.roundcards, Enum.at(state.round_order, 0)))

    Enum.any?(state.cards[dir], fn c -> suit(c) == lead_suit end) and
      suit(card) != lead_suit
  end

  @doc """
  apply_play：执行出牌，返回更新后的 state。
    - 从手牌移除该牌
    - 写入 roundcards[dir]
    - 扣减 card_count
    - roundcard_count + 1
  """
  def apply_play(state, dir, card) do
    cards = %{state.cards | dir => List.delete(state.cards[dir], card)}

    %{
      state
      | cards: cards,
        roundcards: Map.put(state.roundcards, dir, card),
        card_count: Map.update!(state.card_count, dir, &(&1 - 1)),
        roundcard_count: state.roundcard_count + 1
    }
  end

  # 首轮禁出：若该牌所在的花被卖（allow_playbid[suit] == 0），不能领出。
  # 忠实映射原文 allow_playbid[SUIT] 的标志位语义。
  defp following_card_sold?(state, _dir, card) do
    flag = Enum.at(state.allow_playbid, suit(card), 1)
    flag == 0
  end

  # ==================== do_bid 校验（自包含部分） ====================

  @doc """
  bid 的纯校验骨架：卖牌去重 + 手牌校验。
  dir: 出价者座位；sold_bits: 已有卖牌位掩码 (bid_flag)
  b: 该牌的卖牌位掩码 (0 表示不可卖)
  Returns :ok | {:error, msg}
  """
  def valid_bid(state, dir, card, sold_bits, b) do
    cond do
      not Map.has_key?(state.pl, dir) -> {:error, "你没有在拱猪！"}
      state.phase != :bidding -> {:error, "现在不是卖牌的时候！"}
      b == 0 -> {:error, "这张牌不能被卖！"}
      Bitwise.band(sold_bits, b) != 0 -> {:error, "这张牌已经被卖过了！"}
      not Enum.member?(state.cards[dir], card) -> {:error, "你手上没有这张牌！"}
      true -> :ok
    end
  end

  # ==================== do_sit / do_leave 校验 ====================

  @doc "座位是否合法"
  def valid_seat?(arg), do: arg in @seats

  @doc "do_sit：坐下，返回更新后的 state（桌长/加人/满员判定由调用方处理）。"
  def sit(state, server, dir) do
    %{state | pl: Map.put(state.pl, dir, server), server: server}
  end

  @doc "do_leave：离座（普通玩家），更新 state。"
  def leave(state, dir) do
    %{state | pl: Map.delete(state.pl, dir)}
  end

  # ==================== 阶段 ====================

  @doc "阶段是否合法"
  def valid_phase?(phase), do: phase in @phases
end
