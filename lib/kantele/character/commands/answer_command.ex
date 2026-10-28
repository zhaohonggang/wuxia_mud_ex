defmodule Kantele.Character.AnswerCommand do
  @moduledoc """
  回答命令：`answer <类型>`

  对应 LPC cmds/std/answer.c 与 moye.c `do_answer`。

  - 当玩家正处于 forge 议价（`Forging` 会话 status=="answer_type"）时，`answer <类型>`
    把选择转交莫邪进程裁决（经 room/forge_answer → forge/answer），由 Kantele.World.ForgingAnswer
    校验类型、填字段、判定干将是否在场并推进锻造链。
  - 否则走原 stub 行为（回答系统/你要回答什么）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Forging

  def run(conn, %{"rest" => type}) do
    case maybe_forge(conn, type) do
      {:ok, conn} -> conn
      :passthrough -> stub_message(conn)
    end
  end

  def run(conn, %{}) do
    case maybe_forge(conn, nil) do
      {:ok, conn} -> conn
      :passthrough -> stub_empty(conn)
    end
  end

  # 若处于 forge 议价态且有类型，则转交莫邪裁决；否则交回原 stub 逻辑。
  defp maybe_forge(conn, type) do
    character = conn.character
    session = Forging.get(character.id)

    if is_nil(session) or session.status != "answer_type" or is_nil(type) or
         String.trim(type) == "" do
      :passthrough
    else
      conn
      |> event("room/forge_answer", %{
        type: String.trim(type),
        target: "moye",
        from_id: character.id,
        from_name: character.name,
        reply_to: self()
      })
      |> then(fn conn -> {:ok, conn} end)
    end
  end

  defp stub_message(conn) do
    conn
    |> render(CommandView, "text", %{text: "回答系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp stub_empty(conn) do
    conn
    |> render(CommandView, "text", %{text: "你要回答什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
