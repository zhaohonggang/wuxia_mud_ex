defmodule Kantele.Character.SwearEvent do
  @moduledoc """
  结拜回应事件处理：处理 right/refuse 回应
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def answer(conn, %{"data" => %{"answer" => "right", "from_id" => from_id, "from_name" => from_name}}) do
    character = conn.character

    cond do
      not character.meta.temp["pending/answer/#{from_id}/right"] ->
        conn
        |> render(CommandView, "text", %{text: "人家现在已经不打算和你结拜了。\n"})
        |> prompt(CommandView, "prompt", %{})

      not living?(character) ->
        conn
        |> render(CommandView, "text", %{text: "人家现在听不到你说的话，还是算了吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        # 接受结拜
        target_brothers = Map.get(conn.character.meta, :brothers, %{})
        target_name = conn.character.name

        # TODO: 获取请求者的信息
        # 简化：记录双方结义
        new_brothers = Map.put(conn.character.meta.brothers || %{}, from_id, from_name)
        new_meta = Map.put(conn.character.meta, :brothers, new_brothers)

        # 清除临时状态
        new_meta = Map.delete(conn.character.meta, "pending/answer/#{from_id}/right")
        new_meta = Map.delete(new_meta, "pending/answer/#{from_id}/refuse")

        new_character = %{conn.character | meta: new_meta}
        new_conn = put_character(conn, new_character)

        new_conn
        |> render(CommandView, "text", %{
          text: "你看着#{from_name}，连连点头道：「#{target_self(conn.character)}正有此意！甚好，甚好！」\n\n" <>
                "只见你们两人齐齐跪下，撮土为香，一起磕头发誓。\n\n" <>
                "      虽非骨肉\n      情同手足\n      " <>
                "不是同年同月同日生\n      但求同年同月同日死\n"
        })
        |> prompt(CommandView, "prompt", %{})
        |> save()
    end
  end

  def answer(conn, %{"data" => %{"answer" => "refuse", "from_id" => from_id, "from_name" => from_name}}) do
    character = conn.character

    # 拒绝结拜
    if character.meta.temp["pending/answer/#{from_id}/refuse"] do
      new_meta = Map.delete(conn.character.meta, "pending/answer/#{from_id}/right")
      new_meta = Map.delete(new_meta, "pending/answer/#{from_id}/refuse")
      new_character = %{conn.character | meta: Map.put(conn.character.meta, "pending/answer/#{from_id}", nil)}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{
        text: "你一皱眉，道：「这……这似乎不太好\n吧？还是改日再说吧！」\n"
      })
      |> prompt(CommandView, "prompt", %{})
      |> save()
    else
      conn
      |> render(CommandView, "text", %{text: "人家现在已经不打算和你结拜了。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp living?(%{attributes: %{"hp" => hp}}) when hp > 0, do: true
  defp living?(_), do: false

  defp target_self(character) do
    RANK_D.query_self(character)
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end