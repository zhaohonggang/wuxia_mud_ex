defmodule Kantele.Character.SuicideCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.SuicideCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  describe "suicide 命令" do
    test "无参数时显示确认提示" do
      p = player()
      conn = SuicideCommand.run(build_conn(p), %{"rest" => ""})
      text = output_text(conn)
      assert text =~ "自杀方式"
      assert text =~ "资料将永远删除"
      assert text =~ "suicide -f"
    end

    test "无参数时空rest时显示确认提示" do
      p = player()
      conn = SuicideCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "自杀方式"
    end

    test "-f参数时显示告别信息" do
      p = player(name: "张三")
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f"})
      text = output_text(conn)
      assert text =~ "永别了"
      assert text =~ "张三"
    end

    test "-f参数时设置halt标志" do
      p = player()
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f"})
      assert conn.private.halt? == true
    end

    test "-f参数时发送prompt为false" do
      p = player()
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f"})
      assert conn.assigns[:prompt] == false
    end
  end
end
