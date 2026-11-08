defmodule Kantele.Character.FameBoardTest do
  @moduledoc """
  `top2` / `topp` 共用数据源与渲染的回归测试。

  会写全局 ETS（FamilyFame / League），故 `async: false`，且每个用例前后
  都把 FamilyFame 复位成 LPC `base_family_fame`。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.FameBoard
  alias Kantele.FamilyFame
  alias Kantele.League
  alias Kantele.Util.ChineseNumber

  setup do
    reset_family_fame()
    on_exit(fn -> reset_family_fame() end)
    :ok
  end

  defp reset_family_fame do
    if Process.whereis(Kantele.FamilyFame), do: FamilyFame.reset()
  end

  describe "FAMILY_D 静态声望表" do
    test "逐条移植 base_family_fame：30 个门派，首末值一致" do
      base = FamilyFame.base()

      assert map_size(base) == 30
      assert base["少林寺"] == 10_000_000
      assert base["武当派"] == 8_000_000
      assert base["镇远镖局"] == 500_000
      # LPC 里被注释掉的几家不参与初始化
      refute Map.has_key?(base, "唐门世家")
      refute Map.has_key?(base, "天地会")
    end

    test "ranking/0 按声望降序" do
      [first, second | _] = FamilyFame.ranking()

      assert first.name == "少林寺"
      assert first.fame == 10_000_000
      assert second.name == "武当派"
    end

    test "无昨日快照时 last() 返回今日，榜单 delta 全为 0" do
      assert FamilyFame.last() == FamilyFame.all()

      board = FameBoard.render("")
      refute board =~ "(+"
      refute board =~ "(-"
      assert board =~ "一共是三十个门派。"
    end
  end

  describe "add_fame / snapshot" do
    test "只改已存在门派，声望钳在 0..10 亿" do
      FamilyFame.add_fame("少林寺", 500)
      assert FamilyFame.all()["少林寺"] == 10_000_500

      FamilyFame.add_fame("查无此派", 999)
      refute Map.has_key?(FamilyFame.all(), "查无此派")

      FamilyFame.add_fame("丐帮", -100_000_000)
      assert FamilyFame.all()["丐帮"] == 0

      FamilyFame.add_fame("丐帮", 2_000_000_000)
      assert FamilyFame.all()["丐帮"] == 1_000_000_000
    end

    test "跨天快照后，声望增长在门派榜里体现为 +delta" do
      FamilyFame.snapshot()
      FamilyFame.add_fame("少林寺", 500)

      assert FamilyFame.last()["少林寺"] == 10_000_000
      assert FamilyFame.all()["少林寺"] == 10_000_500

      row =
        FameBoard.render("")
        |> String.split("\n")
        |> Enum.find(&String.contains?(&1, "少林寺"))

      assert row =~ "(+500)"
    end

    test "复位后恢复初始表并清空昨日快照" do
      FamilyFame.snapshot()
      FamilyFame.add_fame("少林寺", 500)
      FamilyFame.reset()

      assert FamilyFame.all() == FamilyFame.base()
      assert FamilyFame.last() == FamilyFame.base()
    end
  end

  describe "LEAGUE_D 昨日快照" do
    test "建盟即记 last_fame，加声望不动快照，跨天快照才推进" do
      if Process.whereis(Kantele.League) do
        name = "榜单测试同盟"
        League.dismiss_league(name)
        on_exit(fn -> League.dismiss_league(name) end)

        assert :ok == League.create_league(name, 100, %{}, "test-leader", "测试")
        assert League.query_league_fame(name) == 100
        assert League.query_all_last_league_fame()[name] == 100

        League.add_league_fame(name, 50)
        assert League.query_league_fame(name) == 150
        assert League.query_all_last_league_fame()[name] == 100

        league_row =
          FameBoard.render("league")
          |> String.split("\n")
          |> Enum.find(&String.contains?(&1, name))

        assert league_row =~ "(+50)"

        League.snapshot_last_fame()
        assert League.query_all_last_league_fame()[name] == 150
      end
    end
  end

  describe "中文数字与参数归一" do
    test "chinese_number 复现 LPC 尾行用字" do
      assert ChineseNumber.to_chinese(0) == "零"
      assert ChineseNumber.to_chinese(1) == "一"
      assert ChineseNumber.to_chinese(10) == "十"
      assert ChineseNumber.to_chinese(30) == "三十"
    end

    test "nil / 空串 / family 同义，其它值无效" do
      family = %{current: %{}, last: %{}}

      assert FameBoard.render(nil, %{family: family}) ==
               FameBoard.render("", %{family: family})

      assert FameBoard.render("", %{family: family}) ==
               FameBoard.render("family", %{family: family})

      assert FameBoard.render("LEVEL", %{family: family}) == "你要看什么排行榜？\n"
    end
  end
end
