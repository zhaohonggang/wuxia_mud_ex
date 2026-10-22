defmodule Kantele.World.ItemDescHandlers.FingerDKiller do
  @moduledoc """
  城门/关卡告示牌（look_gaoshi）handler。

  对应 LPC `d/city/...` 各城门的 `look_gaoshi()`：

      string look_gaoshi()
      {
          return FINGER_D->get_killer() + "\\n" + "<本城知府/提督落款>";
      }

  本 handler 调用 `FingerD.get_killer_text()` 拿到通缉名单正文，再追加上本房
  间 UCL 配置里的 `footer`（各城落款，如 `成都提督\\n吴天德\\n`），交给
  `CommandView` 渲染。

  `footer` 由数据决定、不写死在代码里，方便各城各自维护落款文案。
  """

  import Kalevala.World.Room.Context

  alias Kalevala.Character.CommandView
  alias Kantele.World.FingerD

  @default_text "这里没有这个东西。\n"

  def run(context, requester, params) do
    config = Map.get(params, :config, %{})
    text = render_text(config)
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp render_text(config) do
    # LPC 里 `FINGER_D->get_killer() + "\n<本城知府/提督落款>"`：
    # 落款配置（footer）本身已含前导 "\n"，直接拼接即可。
    footer = Map.get(config, "footer", "")
    killer_text = FingerD.get_killer_text()
    killer_text <> footer
  end

  defp ensure_newline(text) when is_binary(text) do
    String.trim_trailing(text) <> "\n"
  end

  defp ensure_newline(_text), do: @default_text
end
