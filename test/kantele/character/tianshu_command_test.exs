defmodule Kantele.Character.TianshuCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.TianshuCommand
  alias Kantele.Character.Vitals

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_meta(conn), do: (conn.private.update_character || conn.character).meta

  test "未选天书时提示" do
    conn = TianshuCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "没有天书的任务"
  end

  test "选择天书" do
    conn = TianshuCommand.run(build_conn(player()), %{"arg" => "select 1"})
    assert output_text(conn) =~ "你决定开始做雪山飞狐了"
    assert PlayerMeta.get_temp(updated_meta(conn), "tianshu/current") == "雪山飞狐"
  end

  test "非法编号被拒绝" do
    conn = TianshuCommand.run(build_conn(player()), %{"arg" => "select x"})
    assert output_text(conn) =~ "只能从"
  end

  test "已选择后显示当前天书" do
    meta = PlayerMeta.put_temp(player().meta, "tianshu/current", "射雕英雄传")
    p = %{player() | meta: meta}
    conn = TianshuCommand.run(build_conn(p), %{})
    assert output_text(conn) =~ "你目前该完成射雕英雄传"
  end

  test "已完成的天书显示刚做完" do
    meta =
      player().meta
      |> PlayerMeta.put_temp("tianshu/current", "连城决")
      |> Map.put(:tianshu_books, %{"连城决" => 1})

    p = %{player() | meta: meta}
    conn = TianshuCommand.run(build_conn(p), %{})
    assert output_text(conn) =~ "你现在刚做完连城决"
  end

  test "status 显示 14 部天书状态" do
    meta = Map.put(player().meta, :tianshu_books, %{"飞狐外传" => 1})
    p = %{player() | meta: meta}
    conn = TianshuCommand.run(build_conn(p), %{"arg" => "status"})

    assert output_text(conn) =~ "飞狐外传：已完成"
    assert output_text(conn) =~ "雪山飞狐：未完成"
  end

  test "tianshu/天书 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("tianshu")
    assert parsed.module == Kantele.Character.TianshuCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("天书")
    assert parsed.module == Kantele.Character.TianshuCommand
  end
end
