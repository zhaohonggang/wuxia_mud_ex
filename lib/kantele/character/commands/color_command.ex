defmodule Kantele.Character.ColorCommand do
  @moduledoc """
  色彩预览：`color`（cmds/usr/color.c）

  Kantele 侧使用 `{c}`/`{red}` 等标签而非 LPC ANSI 序列，输出
  一张可用色彩名称的对照表，供玩家在昵称/频道等场景选用。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  @palette [
    {"BLK", "黑色", "black"},
    {"RED", "红色", "red"},
    {"GRN", "绿色", "green"},
    {"YEL", "黄色", "yellow"},
    {"BLU", "蓝色", "blue"},
    {"MAG", "品红", "magenta"},
    {"CYN", "青色", "cyan"},
    {"WHT", "白色", "white"}
  ]

  def run(conn, _params) do
    rows =
      Enum.map_join(@palette, "", fn {code, zh, _color} ->
        "  #{code} - #{zh}\n"
      end)

    text = "色彩对照表（在昵称/文字中使用 {color}...{/color} 包裹）：\n#{rows}"

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
