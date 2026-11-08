defmodule Kantele.Character.Top2CommandTest do
  # 有一例走真实 FamilyFame ETS 数据源；与 fame_board_test 的写操作错开，
  # 故本模块不并发执行。
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.Top2Command
  alias Kantele.Character.ToppCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @family %{
    current: %{"少林寺" => 100, "武当派" => 80, "丐帮" => 60},
    last: %{"少林寺" => 90, "武当派" => 90, "丐帮" => 60}
  }

  @league %{
    current: %{"桃园结义" => 500, "清风寨" => 300, "铁血盟" => 100},
    last: %{"桃园结义" => 400, "清风寨" => 350, "铁血盟" => 100}
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

  defp build(sources) do
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
    build(sources) |> Top2Command.run(params) |> output_text()
  end

  describe "裸命令 / family 门派榜" do
    test "裸 top2 出 LPC 门派榜头、行与中文数字尾" do
      text = run(%{}, %{family: @family})

      assert text =~ "目前江湖上所有名门大派的声望状况\n"
      assert text =~ "--------------------------------\n"
      assert text =~ "一共是三个门派。\n"
      refute text =~ "暂未开放"
    end

    test "按声望降序，delta 正数带 +、负数带 -、零不带符号" do
      text = run(%{"category" => "family"}, %{family: @family})

      shaolin = String.split(text, "\n") |> Enum.find(&String.contains?(&1, "少林寺"))
      wudang = String.split(text, "\n") |> Enum.find(&String.contains?(&1, "武当派"))
      gaibang = String.split(text, "\n") |> Enum.find(&String.contains?(&1, "丐帮"))

      assert shaolin =~ " 1. "
      assert shaolin =~ "100"
      assert shaolin =~ "(+10)"
      assert wudang =~ " 2. "
      assert wudang =~ "(-10)"
      assert gaibang =~ " 3. "
      assert gaibang =~ "(0)"
    end

    test "CJK 名字按显示列宽补齐 12 列" do
      text = run(%{}, %{family: @family})
      row = String.split(text, "\n") |> Enum.find(&String.contains?(&1, "少林寺"))

      # " 1. " + 3 汉字(6 列) + 6 空格 + 2 空格 + fame 字段
      assert row =~ "少林寺      "
    end

    test "family 参数与裸命令等价" do
      assert run(%{"category" => "family"}, %{family: @family}) ==
               run(%{}, %{family: @family})
    end

    test "空门派表照样出表头与「零个门派」" do
      empty = %{current: %{}, last: %{}}
      text = run(%{}, %{family: empty})

      assert text =~ "目前江湖上所有名门大派的声望状况"
      assert text =~ "一共是零个门派。"
    end

    test "不注入数据源时走真实 FAMILY_D 静态表（30 个门派）" do
      text = run(%{})

      assert text =~ "少林寺"
      assert text =~ "10000000"
      assert text =~ "镇远镖局"
      assert text =~ "一共是三十个门派。"
    end
  end

  describe "league 同盟榜" do
    test "空同盟返回 LPC notify_fail 文案" do
      text = run(%{"category" => "league"}, %{league: %{current: %{}, last: %{}}})

      assert text == "目前江湖上没有什么有名的结义同盟。\n"
    end

    test "按声望降序列出，尾部用中文数字" do
      text = run(%{"category" => "league"}, %{league: @league})

      assert text =~ "目前江湖上著名结义同盟的声望状况\n"
      assert text =~ "列出了三个结义同盟。\n"
      assert text =~ "桃园结义"
      assert text =~ "清风寨"
      assert text =~ "铁血盟"
      assert text =~ "(+100)"
      assert text =~ "(-50)"
      refute text =~ "一共有"
    end

    test "最多只列 30 个同盟" do
      current = Map.new(1..35, fn i -> {"同盟#{i}", 1000 - i} end)
      text = run(%{"category" => "league"}, %{league: %{current: current, last: %{}}})

      assert text =~ "列出了三十个结义同盟。"
      assert text =~ "同盟1"
      assert text =~ "同盟30"
      refute text =~ "同盟31"
      refute text =~ "31. "
    end
  end

  describe "参数校验" do
    test "未知类别回 LPC 提示" do
      assert run(%{"category" => "kill"}) == "你要看什么排行榜？\n"
    end

    test "league 后有多余文字整段都算非法参数" do
      assert run(%{"category" => "league 多余"}) == "你要看什么排行榜？\n"
    end

    test "参数首尾空白按 LPC arg 语义去除" do
      assert run(%{"category" => "  family  "}, %{family: @family}) =~
               "目前江湖上所有名门大派的声望状况"
    end
  end

  describe "路由解析" do
    test "裸 top2 仍解析到 Top2Command.run" do
      {:ok, parsed} = Kantele.Character.Commands.parse("top2")

      assert parsed.module == Top2Command
      assert parsed.function == :run
    end

    test "top2 family / league 把整段文字收进 category" do
      {:ok, family} = Kantele.Character.Commands.parse("top2 family")
      {:ok, league} = Kantele.Character.Commands.parse("top2 league")

      assert family.params["category"] == "family"
      assert league.params["category"] == "league"
    end

    test "top2 与 topp 输出一致（LPC 两份源码内容相同）" do
      sources = %{family: @family, league: @league}

      assert run(%{}, sources) ==
               (build(sources) |> ToppCommand.run(%{}) |> output_text())

      assert run(%{"category" => "league"}, sources) ==
               (build(sources) |> ToppCommand.run(%{"category" => "league"}) |> output_text())
    end
  end
end
