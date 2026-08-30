defmodule Kantele.Character.AskQuestCommand do
  @moduledoc """
  请求任务：`ask_quest <NPC>` / `cancel_quest <NPC>` / `问任务 <NPC>` / `取消任务 <NPC>`

  向目标 NPC 发起请求任务或取消任务。
  NPC 需要有 quest 配置（可发布的任务规格）。
  """

  use Kalevala.Character.Command

  def run(conn, %{"name" => name}) do
    conn
    |> event("quest/ask", %{name: name})
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Character.CancelQuestCommand do
  use Kalevala.Character.Command

  def run(conn, %{"name" => name}) do
    conn
    |> event("quest/cancel", %{name: name})
    |> assign(:prompt, false)
  end
end