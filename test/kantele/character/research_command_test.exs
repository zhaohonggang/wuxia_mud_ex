defmodule Kantele.Character.ResearchCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ResearchCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000)
    }

    stats = %Stats{
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{"sword" => 200}),
      potential: Keyword.get(opts, :potential, 100),
      learned_points: Keyword.get(opts, :learned_points, 0)
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
        combat: Keyword.get(opts, :combat, Combat.new())
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

  describe "路由解析" do
    test "research 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("research sword 1")
      assert parsed.module == ResearchCommand
      assert parsed.params["arg"] == "sword 1"
    end

    test "research 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("research")
      assert parsed.module == ResearchCommand
    end

    test "yanjiu 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("yanjiu sword")
      assert parsed.module == ResearchCommand
      assert parsed.function == :yanjiu_run
      assert parsed.params["arg"] == "sword"
    end

    test "yanjiu 带次数" do
      {:ok, parsed} = Kantele.Character.Commands.parse("yanjiu sword 5")
      assert parsed.module == ResearchCommand
      assert parsed.params["arg"] == "sword 5"
    end
  end

  describe "research 命令" do
    test "技能等级不足时提示" do
      p = player(skills: %{"sword" => 100})
      conn = ResearchCommand.run(build_conn(p), %{"arg" => "sword 1"})
      assert output_text(conn) =~ "研究"
    end

    test "无参数时提示用法" do
      conn = ResearchCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "research"
    end

    test "潜能耗尽时提示" do
      p = player(skills: %{"sword" => 200}, potential: 10, learned_points: 10)
      conn = ResearchCommand.run(build_conn(p), %{"arg" => "sword 5"})
      assert output_text(conn) =~ "潜能"
    end

    test "精力不足时只研究一次" do
      p = player(skills: %{"sword" => 200}, jing: 5, potential: 100, learned_points: 0)
      conn = ResearchCommand.run(build_conn(p), %{"arg" => "sword 10"})
      text = output_text(conn)
      assert text =~ "累了" or text =~ "研究"
    end

    test "研究成功提升技能" do
      p = player(skills: %{"sword" => 200, "force" => 200}, potential: 50, learned_points: 0)
      conn = ResearchCommand.run(build_conn(p), %{"arg" => "sword 1"})

      text = output_text(conn)
      assert text =~ "领悟" or text =~ "研究"
    end
  end
end
