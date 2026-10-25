defmodule Kantele.World.Casino do
  @moduledoc """
  赌场（city:bet）核心逻辑（纯函数，无副作用）。

  移植自 `d/city/bet.c` 的 `do_bet` + 开盘/封盘/摇骰/结算四段 `call_out` 序列。
  房间状态（存 `Room` 的 `state["casino"]`，仅内存）：

  - `status`：`0` 未开盘 / `1` 押注中 / `2` 封盘中
  - `big`：`{b1, b2}` 头彩骰（两枚不同，概率 1/36），开盘时确定
  - `res`：`[r0, r1]` 开盅骰，摇盅时分两次确定
  - `bettors`：`[%{player_id, name, kind, amount}]` 本盘下注者

  ## 赔率（对应 LPC `gutous`）

  | 种类 | 条件 | 倍率 |
  |------|------|------|
  | `tc` 头彩 | `res == big` | 36 |
  | `sd` 双对 | `r0 == r1` 且为偶数 | 12 |
  | `qx` 七星 | `r0 + r1 == 7` | 6 |
  | `sx` 散星 | `r0 + r1 ∈ {3,5,9,11}` | 3 |
  | 其它 | — | 0 |

  ## 与 LPC 的差异 / 简化

  - LPC 的 `money` 区分 gold/silver/coin 三种通货（`present(money+"_money", me)` +
    `base_value` 折算上限 10 两黄金）。本移植货币是扁平铜钱 `meta.coins`，**押注额
    直接按铜钱计**，货币种类 token 仅作语法占位、不参与折算（见 `City.Bet`）。
  - LPC 用 `call_out` 串起 `prepare→start→perform×2→finish` 的定时序列；本移植用
    `:timer.apply_after`（同 `RoomActions.Vehicle`），由 `City.Bet` 负责定时器编排，
    本模块只提供每个阶段的纯计算。
  - RNG 以可注入的 `rng` 函数（默认 `:rand.uniform(6)`）传入，便于测试确定性复现。
  """
  @kinds ~w(tc sd qx sx)
  @payouts %{"tc" => 36, "sd" => 12, "qx" => 6, "sx" => 3}

  @doc "初始（未开盘）状态。"
  def new, do: %{status: 0, big: nil, res: nil, bettors: []}

  @doc """
  开盘：确定头彩骰（两枚不同，保证 1/36 概率）、清空本盘下注者、置 `status = 1`。
  `rng` 须返回 1..6 的整数。
  """
  def prepare(state, rng \\ fn -> :rand.uniform(6) end) do
    d1 = rng.()
    d2 = pick_distinct(rng, d1)
    %{state | status: 1, big: {d1, d2}, res: nil, bettors: []}
  end

  defp pick_distinct(rng, d1) do
    d2 = rng.()
    if d2 == d1, do: pick_distinct(rng, d1), else: d2
  end

  @doc """
  押注。返回 `{:ok, state}` 或 `{:error, msg}`（msg 为给行动者的提示，含换行）。

  校验顺序（对应 LPC `do_bet` 的若干 `notify_fail`）：
  非押注窗口 / 押注种类非法 / 数量 < 1 / 已押过。
  扣币由调用方（`City.Bet`）负责——本模块只记录意图。
  """
  def place_bet(state, player, kind, amount)
      when is_binary(kind) and is_integer(amount) do
    cond do
      state.status != 1 ->
        {:error, "庄家赔笑道：现在正在赌呢，请你稍等片刻。\n"}

      not (kind in @kinds) ->
        {:error, "庄家皱眉道：你要押哪一种骰？\n"}

      amount < 1 ->
        {:error, "庄家皱眉道：那么少？不够，不够，再多押点。\n"}

      already_bet?(state, player.id) ->
        {:error, "庄家道：你已经押过了，就等着开盅吧。\n"}

      true ->
        bettor = %{player_id: player.id, name: player.name, kind: kind, amount: amount}
        {:ok, %{state | bettors: [bettor | state.bettors]}}
    end
  end

  defp already_bet?(state, player_id),
    do: Enum.any?(state.bettors, &(&1.player_id == player_id))

  @doc "封盘：押注窗口关闭（`status = 2`）。"
  def start(state), do: %{state | status: 2}

  @doc """
  摇出第 `i` 枚开盅骰（`i ∈ {0,1}`），写入 `res`。`rng` 返回 1..6。
  """
  def perform(state, i, rng \\ fn -> :rand.uniform(6) end) when i in [0, 1] do
    r = rng.()
    res = List.replace_at(state.res || [nil, nil], i, r)
    %{state | res: res}
  end

  @doc """
  结算：判定赢家种类与倍率，返回 `{state, winner_kind, total, payouts}`。

  - `winner_kind`：`tc/sd/qx/sx/none`
  - `total`：倍率（赢家种类的赔率，0 表示空盘）
  - `payouts`：`[%{player_id, name, kind, amount, won, payout}]`，`payout = total * amount`
    当 `won`，否则 0。结算后 `status` 归 0、`bettors` 清空（等待下一盘）。
  """
  def finish(state) do
    {winner, total} = resolve(state.big, state.res)
    payouts = Enum.map(state.bettors, fn b ->
      won = b.kind == winner
      b |> Map.put(:won, won) |> Map.put(:payout, if(won, do: total * b.amount, else: 0))
    end)

    {%{state | status: 0, bettors: []}, winner, total, payouts}
  end

  # 头彩 > 双对 > 七星 > 散星 > 空盘（顺序与 LPC `gamble_finish` 一致）。
  defp resolve({b1, b2}, [r1, r2]) do
    cond do
      r1 == b1 and r2 == b2 -> {"tc", 36}
      r1 == r2 and rem(r1, 2) == 0 -> {"sd", 12}
      r1 + r2 == 7 -> {"qx", 6}
      r1 + r2 in [3, 5, 9, 11] -> {"sx", 3}
      true -> {"none", 0}
    end
  end

  defp resolve(_big, _res), do: {"none", 0}

  @doc "赢家种类的赔率（未知种类返回 0）。"
  def payout(kind), do: Map.get(@payouts, kind, 0)

  @doc "押注种类的可读名（对应 LPC `gutous`）。"
  def kind_name("tc"), do: "头彩"
  def kind_name("sd"), do: "双对"
  def kind_name("qx"), do: "七星"
  def kind_name("sx"), do: "散星"
  def kind_name(other), do: other
end
