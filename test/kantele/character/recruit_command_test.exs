defmodule Kantele.Character.RecruitCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.RecruitCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20)
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        family: Keyword.get(opts, :family, %{"family_name" => "少林派"}),
        team_pending: Keyword.get(opts, :team_pending, nil)
      }
    }
  end

  describe "路由解析" do
    test "recruit 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("recruit")
      assert parsed.module == RecruitCommand
    end

    test "shou 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("shou")
      assert parsed.module == RecruitCommand
    end
  end

  describe "recruit 命令" do
    test "无参数时报指令格式错误" do
      p = player()
      conn = RecruitCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "指令格式"
    end

    test "无门派不能收徒" do
      p = player(family: nil)
      conn = RecruitCommand.run(build_conn(p), %{"arg" => "某人"})
      text = output_text(conn)
      assert text =~ "并不属于任何门派"
    end

    test "cancel无待收弟子时报错" do
      p = player(team_pending: nil)
      conn = RecruitCommand.run(build_conn(p), %{"arg" => "cancel"})
      text = output_text(conn)
      assert text =~ "并没有收录任何人"
    end

    test "cancel有pending时取消收录" do
      p = player(team_pending: %{"recruit" => "某人"})
      conn = RecruitCommand.run(build_conn(p), %{"arg" => "cancel"})
      text = output_text(conn)
      assert text =~ "改变主意不想收人为弟子"
    end

    test "有门派收某人为弟子" do
      p = player()
      conn = RecruitCommand.run(build_conn(p), %{"arg" => "某人"})
      text = output_text(conn)
      assert text =~ "你想收某人为弟子"
    end
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
