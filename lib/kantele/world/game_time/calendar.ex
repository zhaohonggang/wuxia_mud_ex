defmodule Kantele.World.GameTime.Calendar do
  @moduledoc """
  Game time arithmetic (Q2-T1)

  - 现实 1s = 游戏 12s（现实 5s = 游戏 1min，LPC DATE_SCALE 12 倍速）
  - 时间轴：`game_seconds = (real_now - real_epoch) * 12 + game_epoch`
    - `real_epoch`：2026-01-01 00:00 UTC（锚点，防漂移）
    - `game_epoch`：1996-01-01 00:00（武侠年代起点；每次换算都从真实墙钟导出，
      重启不会累计漂移）
  - 时区固定 UTC+8 墙钟（北京时间感，固定偏移不依赖 tzdata），季节直接按月
    （不搞独立游戏历法年）：春 3-5 / 夏 6-8 / 秋 9-11 / 冬 12-2
  """

  @rate 12
  @real_epoch_second 1_767_225_600
  @game_epoch_second 820_454_400

  @doc "游戏倍率：现实 1 秒 = 游戏 #{@rate} 秒"
  def rate(), do: @rate

  # 时区固定 UTC+8（北京时间感），用固定偏移量换算，避免依赖外部 tzdata：
  # 直接对游戏秒 +8h 后按 UTC 读钟，得到与 UTC+8 一致的墙钟字段。
  @tz_offset_seconds 28_800

  @doc "真实秒 → 游戏秒"
  def game_seconds(real_now) when is_integer(real_now) do
    (real_now - @real_epoch_second) * @rate + @game_epoch_second
  end

  @doc "真实秒 → 游戏 DateTime（墙钟按 UTC+8 偏移）"
  def datetime(real_now) when is_integer(real_now) do
    game_seconds(real_now) + @tz_offset_seconds
    |> DateTime.from_unix!()
  end

  @doc "真实秒 → 游戏钟表 %{year, month, day, hour, minute, second}"
  def localtime(real_now) when is_integer(real_now) do
    dt = datetime(real_now)

    %{
      year: dt.year,
      month: dt.month,
      day: dt.day,
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second
    }
  end

  @doc "月份 → 季节（春 3-5 / 夏 6-8 / 秋 9-11 / 冬 12-2）"
  def season(month) when month in 3..5, do: :spring
  def season(month) when month in 6..8, do: :summer
  def season(month) when month in 9..11, do: :autumn
  def season(month) when month in [12, 1, 2], do: :winter
end