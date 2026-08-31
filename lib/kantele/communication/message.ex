defmodule Kantele.Communication.Message do
  @moduledoc """
  消息类 → 颜色 / 提示符 / 输入缓冲（对应 `feature/message.c`）

  纯逻辑部分，供宿主 receive_message/write_prompt 接入：

  - `color_class/1`: 消息类映射 ANSI 颜色（对应 message.c receive_message 的 switch）
  - `prompt_prefix/2`: 按 `env/prompt`（time/date/mud/hp/path）生成提示前缀
  - `buffer_message/3`: 玩家输入期间消息入缓冲（上限 MAX_MSG_BUFFER=500），
    返回 `{:buffered, buf}` / `{:dropped, buf}`
  - `drain_buffer/1` + `is_waiting?/written` 状态机（clear_written/is_waiting_command）
  """

  @max_msg_buffer 500
  @none 0
  @prompt_written 1
  @command_rcvd 2

  @ansi %{
    # HIC
    info: "\e[36m",
    # HIG
    success: "\e[32m",
    # HIY
    warning: "\e[33m",
    # HIR
    error: "\e[31m",
    # HIR
    danger: "\e[31m",
    # HIM
    him: "\e[35m",
    # MAG
    mag: "\e[35m",
    # CYN
    cyn: "\e[36m",
    # RED
    red: "\e[31m",
    # GRN
    grn: "\e[32m",
    # BLU
    blu: "\e[34m",
    # YEL
    yel: "\e[33m",
    # NOR
    reset: "\e[0m"
  }

  @doc "消息类 → (ANSI 前缀, ANSI 后缀)；无映射返回 nil/裸文本（LPC default receive(msg)）"
  def color_class(nil), do: nil
  def color_class("info"), do: {@ansi.info, @ansi.reset}
  def color_class("success"), do: {@ansi.success, @ansi.reset}
  def color_class("warning"), do: {@ansi.warning, @ansi.reset}
  def color_class("error"), do: {@ansi.error, @ansi.reset}
  def color_class("danger"), do: {@ansi.error, @ansi.reset}
  def color_class("HIM"), do: {@ansi.him, @ansi.reset}
  def color_class("MAG"), do: {@ansi.mag, @ansi.reset}
  def color_class("CYN"), do: {@ansi.cyn, @ansi.reset}
  def color_class("RED"), do: {@ansi.red, @ansi.reset}
  def color_class("GRN"), do: {@ansi.grn, @ansi.reset}
  def color_class("BLU"), do: {@ansi.blu, @ansi.reset}
  def color_class("YEL"), do: {@ansi.yel, @ansi.reset}
  def color_class(_), do: nil

  @doc """
  染色：返回带颜色的消息（message.c switch 后 receive(prefix+msg+nor)）。
  无映射类原样返回。
  """
  def s(color_class_str, msg) do
    case color_class(color_class_str) do
      nil -> msg
      {pre, post} -> pre <> msg <> post
    end
  end

  @doc "提示符前缀（LPC prompt() 的 env/prompt 分支）；返回 default 前缀 + 附加"
  def prompt_prefix(env_prompt, time_info \\ %{}) do
    base = "> "

    case env_prompt do
      "time" ->
        "\e[36m" <> (Map.get(time_info, :time) || "") <> base

      "date" ->
        "\e[36m" <> (Map.get(time_info, :date) || "") <> base

      "mud" ->
        "\e[36m" <> (Map.get(time_info, :game_time) || "") <> base

      "hp" ->
        "\e[32m" <> Map.get(time_info, :hp, "") <> base

      "path" ->
        "\e[36m" <> (Map.get(time_info, :path) || "") <> base

      p when is_binary(p) ->
        p <> base

      _ ->
        base
    end
  end

  @doc """
  receive_message 输入期间缓冲

  - 输入/编辑/附加系统中 + 类非 system → 入缓冲（≤500）
  - 否则 :out（直接送出）
  """
  def buffer_message(buffer, msg) do
    if length(buffer) < @max_msg_buffer do
      {:buffered, buffer ++ [msg]}
    else
      {:dropped, buffer}
    end
  end

  @doc "write_prompt 前先清空缓冲；返回 `{drained_msgs, empty_buffer}`"
  def drain_buffer(buffer) do
    if buffer == [] do
      {[], []}
    else
      {["\e[1m[输入时暂存讯息]\e[0m\n"] ++ buffer, []}
    end
  end

  @doc "written 状态机（LPC clear_written/write_prompt/is_waiting_command）"
  def clear_written(_), do: @command_rcvd
  def write_prompt_mark(_), do: @prompt_written
  def reset_written(_), do: @none
  def is_waiting_command?(@prompt_written), do: true
  def is_waiting_command?(_), do: false

  @doc "写提示前是否补清行（LPC primitive）"
  def prompt_escape(), do: "\e[256D"
end
