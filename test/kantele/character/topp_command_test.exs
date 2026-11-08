defmodule Kantele.Character.ToppCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Top2Command
  alias Kantele.Character.ToppCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @family %{
    current: %{"全真教" => 60, "少林寺" => 100},
    last: %{"全真教" => 60, "少林寺" => 100}
  }

  @league %{
    current: %{"一字盟" => 20},
    last: %{"一字盟" => 15}
  }

  defp player do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      combat_exp: 0,
      score: 0,
      weiwang: 0
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
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp build(sources \\ %{}) do
    conn = build_conn(player())
    %{conn | private: Map.put(conn.private, :fame_board, sources)}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp run(params, sources \\ %{}) do
    build(sources) |> ToppCommand.run(params) |> output_text()
  end

  describe "topp 命令" do
    test "裸命令出门派榜，不再是占位文案" do
      text = run(%{}, %{family: @family})

      assert text =~ "目前江湖上所有名门大派的声望状况"
      assert text =~ "一共是二个门派。"
      refute text =~ "暂未开放"
      refute text =~ "排行榜暂未"
    end

    test "topp league 出同盟榜" do
      text = run(%{"category" => "league"}, %{league: @league})

      assert text =~ "目前江湖上著名结义同盟的声望状况"
      assert text =~ "一字盟"
      assert text =~ "(+5)"
      assert text =~ "列出了一个结义同盟。"
    end

    test "未知类别回 LPC 提示" do
      assert run(%{"category" => "whatever"}) == "你要看什么排行榜？\n"
    end

    test "同盟榜为空时回 notify_fail 文案" do
      text = run(%{"category" => "league"}, %{league: %{current: %{}, last: %{}}})

      assert text == "目前江湖上没有什么有名的结义同盟。\n"
    end

    test "与 top2 的 family 输出完全一致" do
      sources = %{family: @family, league: @league}

      assert run(%{}, sources) ==
               (build(sources) |> Top2Command.run(%{}) |> output_text())
    end

    test "与 top2 的非法参数输出完全一致" do
      assert run(%{"category" => "nope"}) ==
               (build() |> Top2Command.run(%{"category" => "nope"}) |> output_text())
    end
  end

  describe "路由解析" do
    test "裸 topp 解析到 ToppCommand.run" do
      {:ok, parsed} = Kantele.Character.Commands.parse("topp")

      assert parsed.module == ToppCommand
      assert parsed.function == :run
    end

    test "topp family / league 收进 category" do
      {:ok, family} = Kantele.Character.Commands.parse("topp family")
      {:ok, league} = Kantele.Character.Commands.parse("topp league")

      assert family.params["category"] == "family"
      assert league.params["category"] == "league"
    end

    test "top 前缀不会抢走 top2 / topp" do
      {:ok, top2} = Kantele.Character.Commands.parse("top2 family")
      {:ok, topp} = Kantele.Character.Commands.parse("topp league")

      assert top2.module == Top2Command
      assert topp.module == ToppCommand
    end
  end
end
