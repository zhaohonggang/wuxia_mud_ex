defmodule Kantele.Character.FingerCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.FingerCommand

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} ->
        [IO.iodata_to_binary(data)]

      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} ->
        [IO.iodata_to_binary(data)]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "finger 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("finger")
      assert parsed.function == :list

      {:ok, parsed} = Kantele.Character.Commands.parse("finger 张三")
      assert parsed.function == :run
      assert parsed.params["name"] == "张三"
    end

    test "中文别名 查找" do
      {:ok, parsed} = Kantele.Character.Commands.parse("查找 张三")
      assert parsed.function == :run
    end
  end

  describe "列出在线" do
    test "无参数列出在线玩家" do
      conn = FingerCommand.list(build_conn(player()), %{})
      assert output_text(conn) =~ "在线玩家"
    end
  end

  describe "查找玩家" do
    test "找不到时提示" do
      conn = FingerCommand.run(build_conn(player()), %{"name" => "不存在的人"})
      assert output_text(conn) =~ "没有找到"
    end
  end
end
