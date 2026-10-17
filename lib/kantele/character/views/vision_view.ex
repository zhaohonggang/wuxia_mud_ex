defmodule Kantele.Character.VisionView do
  @moduledoc """
  房间 vision 消息渲染（对应 LPC `message_vision`）

  事件 `text` 是**模板**：`{name}`（物品名，与观看者无关）由发布方
  在入队前替换；`{npc}`（行动者）留给本视图按接收者渲染 —— 与
  `SayView` 的 echo/listen 分流同构：

  - `echo`（行动者自己收到）：`{npc}` → `你`
  - `listen`（房间内其他人收到）：`{npc}` → 行动者姓名

  LPC 源即 `$N`/`$n` 占位符（转换器归一化为 `{npc}`/`{name}`，
  见 `lpc_converter.ex` 的 `escape_set_string`）。
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  @doc "行动者视角：{npc} → 你"
  def render("echo", %{text: text}) do
    render_text(String.replace(text, "{npc}", "你"))
  end

  @doc "旁观者视角：{npc} → 行动者姓名（纯文本，不做 character 标签包裹）"
  def render("listen", %{text: text, character: character}) do
    name = Map.get(character, :name) || "某人"
    render_text(String.replace(text, "{npc}", name))
  end

  defp render_text(text) do
    %EventText{
      topic: "Room.Vision",
      data: %{text: text},
      text: text
    }
  end
end
