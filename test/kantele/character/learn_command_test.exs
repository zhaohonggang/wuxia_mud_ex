defmodule Kantele.Character.LearnCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.{LearnCommand, PracticeCommand}
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

  describe "learn 命令" do
    test "发送 skills/learn 事件" do
      p = player()
      conn = LearnCommand.run(build_conn(p), %{"skill" => "sword", "name" => "王重九"})
      assert Enum.any?(conn.events, fn e -> e.topic == "skills/learn" end)
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("learn sword 王重阳")
      assert parsed.module == LearnCommand
    end
  end

  describe "practice 命令" do
    test "无效技能时提示" do
      p = player()
      conn = PracticeCommand.run(build_conn(p), %{"skill" => "nonexistent"})
      assert Enum.any?(conn.output, fn
        %Kalevala.Character.Conn.Text{data: data} -> IO.iodata_to_binary(data) =~ "没有这项武功"
        _ -> false
      end)
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("practice sword")
      assert parsed.module == PracticeCommand
    end
  end
end
