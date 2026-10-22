defmodule Kantele.World.ItemDescHandlers.ArenaState do
  @moduledoc """
  数据驱动动态 `item_desc`：按擂台「关闭 / 开放」状态（`Kantele.World.Arena`）渲染条幅文本（P5-4n）。

  对应 LPC `d/city/leitai.c` 的 `look_tiaofu()`：

      object ob = query("close_by");
      if (! objectp(ob))
          return "本擂台现在自由开放……（开放说明）";
      return "本擂台现在被" + ob->name(1) + "暂时关闭……（关闭说明）";

  LPC 的 `query("close_by")` 在 Elixir 侧由 `Kantele.World.Arena.close_by(room_id)` 实现，
  返回 `nil`（开放）或 `%{by: 关闭者名}`（关闭）。关闭分支文本里的 `{name}` 占位符在运行期
  被替换为 `by`。占位符可用 `name_token` 字段覆盖（默认 `"{name}"`）。

  UCL 示例：

      item_desc = {
       tiaofu = {
        kind = "arena_state"
        open_text = "本擂台现在自由开放，如有兴趣自行比武，失手伤人致命，概不负责。\\n\\n注：巫师请用 lopen/lclose 命令开放关闭擂台。"
        closed_text = "本擂台现在被 {name} 暂时关闭，组织比武，闲杂人等勿要喧哗。\\n巫师请用 invite 命令邀请他人上台，或在台下使用 pass 命令\\n指定某人上台比武，用 kickout 踢某人下台。"
       }
      }

  `Arena.close_by/1` 走 ETS 直读、fail-safe（异常当作开放），与本 handler「无状态时回落开放文本」
  的语义天然一致：`nil` 既可能是「真没关闭」，也可能是「缓存未起」——两种情况都回开放文本更稳。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.World.Arena

  @default_text "这里没有这个东西。\n"
  @name_token "{name}"

  def run(context, requester, params) do
    room_id = Map.get(params, :room_id)
    config = Map.get(params, :config, %{})
    text = render_text(room_id, config)
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  # 读 Arena 关闭状态：nil / 非 map → 开放文本；%{by: 名} → 把 name 插进关闭文本。
  defp render_text(room_id, config) when is_binary(room_id) do
    case Arena.close_by(room_id) do
      nil ->
        Map.get(config, "open_text") || @default_text

      %{by: by} when is_binary(by) ->
        interpolate(Map.get(config, "closed_text") || @default_text, by, config)

      _ ->
        Map.get(config, "open_text") || @default_text
    end
  end

  defp render_text(_room_id, config), do: Map.get(config, "open_text") || @default_text

  defp interpolate(text, name, config) when is_binary(text) do
    token = Map.get(config, "name_token", @name_token)
    String.replace(text, token, to_string(name))
  end

  defp interpolate(_text, _name, _config), do: @default_text

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end
