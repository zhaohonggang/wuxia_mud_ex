defmodule Kantele.Character.ColorCommand do
  @moduledoc """
  颜色命令：`color`

  对应 LPC cmds/usr/color.c。
  显示游戏中可用的 ANSI 色彩控制字元及色样，方便选择中意的色彩。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    header = "\e[35m·\e[33m色彩精灵向您报告\e[35m★\n\n\e[1m色彩对照表：\n"
    swatches = [
      "  黑色  BLK                \e[30m■■\e[0m    BBLK  \e[1;30m■■\e[0m\n",
      "  红色  RED                \e[31m■■\e[0m    HIR   \e[1;31m■■\e[0m\n",
      "  绿色  GRN                \e[32m■■\e[0m    HIG   \e[1;32m■■\e[0m\n",
      "  黄色  YEL                \e[33m■■\e[0m    HIY   \e[1;33m■■\e[0m\n",
      "  蓝色  BLU                \e[34m■■\e[0m    HIB   \e[1;34m■■\e[0m\n",
      "  品红  MAG                \e[35m■■\e[0m    HIM   \e[1;35m■■\e[0m\n",
      "  青色  CYN                \e[36m■■\e[0m    HIC   \e[1;36m■■\e[0m\n",
      "  白色  WHT                \e[37m■■\e[0m    HIW   \e[1;37m■■\e[0m\n"
    ]

    conn
    |> render(CommandView, "text", %{text: header <> Enum.join(swatches)})
    |> prompt(CommandView, "prompt", %{})
  end
end