defmodule Kantele.Character.WhistleCommand do
  @moduledoc """
  召唤坐骑：`whistle <summon_id>` / `xiao <summon_id>`（对应 LPC whistle 指令）

  从仓库/马厩将坐骑召唤到背包。需验证 owner 权限。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Mount

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        conn
        |> render(CommandView, "text", %{text: "你要召唤什么？\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        do_whistle(conn, rest)
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp do_whistle(conn, summon_id) do
    case Mount.summon(conn.character, summon_id) do
      {:ok, instance} ->
        # 已在背包，检查是否已骑乘
        if Map.get(conn.character.meta, :riding) != nil do
          conn
          |> render(CommandView, "text", %{text: "你已经有座骑了！\n"})
          |> prompt(CommandView, "prompt", %{})
        else
          conn
          |> render(CommandView, "text", %{text: "你吹了声口哨，#{instance.item.name} 奔了过来。\n"})
          |> prompt(CommandView, "prompt", %{})
        end

      {:error, msg} ->
        conn
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end
end
