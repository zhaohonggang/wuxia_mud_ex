defmodule Kantele.Character.NpcInitEvent do
  @moduledoc """
  NPC `init()` 触发的玩家侧回执。

  当前只承载庄允城 `init()`（Task #1245，LPC `d/beijing/npc/zhuangyu.c:45-62`）：
  NPC 进程算出最终威望后发 `npc/init/weiwang`，玩家进程自己写
  `meta.stats.weiwang` 并显示 `command("tell <id> ...")` 的私有文案。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  @doc "LPC `this_player()->set(\"weiwang\", i)` + `command(\"tell ...\")`。"
  def weiwang(conn, %{data: %{weiwang: value}}) when is_integer(value) do
    character = conn.character
    meta = character.meta
    stats = put_weiwang(meta.stats, value)
    updated = %{character | meta: %{meta | stats: stats}}

    conn
    |> put_character(updated)
    |> render(CommandView, "text", %{text: "你现在的江湖威望是 #{value}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def weiwang(conn, _event), do: conn

  defp put_weiwang(%Stats{} = stats, value), do: %{stats | weiwang: value}

  defp put_weiwang(stats, value) when is_map(stats) do
    Map.put(stats, :weiwang, value)
  end

  defp put_weiwang(_stats, value), do: %{struct(Stats, []) | weiwang: value}
end
