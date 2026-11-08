defmodule Kantele.Character.PkdCommand do
  @moduledoc """
  屠人场命令：`pkd`

  对应 LPC `cmds/usr/pkd.c`。

  用法：
  - `pkd`：显示赛事状态与全部竞争者
  - `pkd join`：报名参加屠人大赛（需 state == :ready）
  - `pkd quit`：退赛

  依赖 `Kantele.Character.Pkd` daemon（PK_D）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Pkd

  @subcommands ~w[join quit]

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    rest = String.trim(rest)

    case String.split(rest, " ") do
      [subcommand] when subcommand in @subcommands ->
        Pkd.ensure!()
        handle_subcommand(conn, subcommand)

      [] ->
        show_status(conn)

      _ ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：pkd | pkd join | pkd quit\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, %{"command" => "pkd"}) do
    show_status(conn)
  end

  def run(conn, %{}) do
    show_status(conn)
  end

  # ---- 显示赛事状态 ----

  defp show_status(conn) do
    Pkd.ensure!()

    state = Pkd.read_state()
    competitors = Pkd.query_all_competitor()

    state_text =
      case state.state do
        :none -> "当前无屠人赛事。"
        :ready -> "屠人赛事正处于报名期，可使用 `pkd join` 报名。"
        :starting -> "屠人赛事即将开始，报名已关闭。"
        :pking -> "屠人赛事正在进行中。"
      end

    competitor_list =
      if length(competitors) > 0 do
        Enum.join(Enum.map(competitors, fn c ->
          "  #{c.name} (经验 #{c.combat_exp})"
        end), "\n")
      else
        "  （暂无竞争者）"
      end

    conn
    |> render(CommandView, "text", %{
      text: "=== 屠人场赛事状态 ===\n#{state_text}\n\n竞争者列表：\n#{competitor_list}\n=====================\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 子命令处理 ----

  defp handle_subcommand(conn, "join") do
    character = conn.character

    case Pkd.reject_join(character) do
      nil ->
        case Pkd.join(character) do
          {:ok, :joined} ->
            conn
            |> render(CommandView, "text", %{text: "你已成功报名屠人大赛，请耐心等待比赛开始。\n"})
            |> prompt(CommandView, "prompt", %{})

          {:error, msg} ->
            conn
            |> render(CommandView, "text", %{text: "#{msg}\n"})
            |> prompt(CommandView, "prompt", %{})
        end

      msg ->
        conn
        |> render(CommandView, "text", %{text: "#{msg}\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp handle_subcommand(conn, "quit") do
    character = conn.character

    case Pkd.quit(character) do
      {:ok, :quit} ->
        conn
        |> render(CommandView, "text", %{text: "你已退出屠人大赛报名。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end
end
