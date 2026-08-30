defmodule Kantele.Character.StatsAttributeTest do
  use ExUnit.Case, async: false

  alias Kantele.Character.Stats

  describe "派生属性查询 (LPC attribute.c 移植)" do
    test "query_str: base + tattoo + reborn + skill/10 + temp" do
      stats = %Stats{
        str: 20,
        skills: %{"unarmed" => 60, "dodge" => 30},
        tattoo: %{str: 5},
        reborn: %{str: 10}
      }

      # base(20) + tattoo(5) + reborn(10) + unarmed/10(6) + temp(0) = 41
      assert Stats.query_str(stats) == 41
    end

    test "query_str with temp applies" do
      stats = %Stats{
        str: 20,
        skills: %{"unarmed" => 60},
        tattoo: %{str: 0},
        reborn: %{str: 0}
      }

      temp_applies = %{str: 8}
      # base(20) + tattoo(0) + reborn(0) + unarmed/10(6) + temp(8) = 34
      assert Stats.query_str(stats, temp_applies) == 34
    end

    test "query_str picks max melee skill" do
      stats = %Stats{
        str: 20,
        skills: %{"unarmed" => 30, "cuff" => 50, "strike" => 10},
        tattoo: %{str: 0},
        reborn: %{str: 0}
      }

      # max(cuff=50, unarmed=30, strike=10) = 50, 50/10 = 5
      # base(20) + 0 + 0 + 5 = 25
      assert Stats.query_str(stats) == 25
    end

    test "query_int: base + tattoo + reborn + literate/10 + temp" do
      stats = %Stats{
        int: 25,
        skills: %{"literate" => 80},
        tattoo: %{int: 3},
        reborn: %{int: 5}
      }

      # base(25) + tattoo(3) + reborn(5) + literate/10(8) = 41
      assert Stats.query_int(stats) == 41
    end

    test "query_con: base + tattoo + reborn + force/10 + temp" do
      stats = %Stats{
        con: 22,
        skills: %{"force" => 50},
        tattoo: %{con: 2},
        reborn: %{con: 0}
      }

      # base(22) + tattoo(2) + reborn(0) + force/10(5) = 29
      assert Stats.query_con(stats) == 29
    end

    test "query_dex: base + tattoo + reborn + dodge/10 + temp" do
      stats = %Stats{
        dex: 18,
        skills: %{"dodge" => 70},
        tattoo: %{dex: 4},
        reborn: %{dex: 8}
      }

      # base(18) + tattoo(4) + reborn(8) + dodge/10(7) = 37
      assert Stats.query_dex(stats) == 37
    end

    test "query_per: base + tattoo + temp - age_penalty" do
      stats = %Stats{
        tattoo: %{per: 2},
        reborn: %{}
      }

      # base(20 default) + tattoo(2) + temp(0) - age_penalty(0, age=30) = 22
      assert Stats.query_per(stats, %{}, 30) == 22
    end

    test "query_per with age penalty" do
      stats = %Stats{
        tattoo: %{per: 0},
        reborn: %{}
      }

      # base(20) + 0 - age_penalty(2, age=35) = 18
      assert Stats.query_per(stats, %{}, 35) == 18
    end

    test "query_per with high age penalty" do
      stats = %Stats{
        tattoo: %{per: 0},
        reborn: %{}
      }

      # base(20) + 0 - 6 (age > 70) = 14
      assert Stats.query_per(stats, %{}, 75) == 14
    end

    test "query_level: pow(combat_exp * 10, 1/3) + 1" do
      stats = %Stats{combat_exp: 1000}

      # pow(10000, 1/3) ≈ 21.5, floor = 21, + 1 = 22
      assert Stats.query_level(stats) == 22
    end

    test "query_level with zero exp" do
      stats = %Stats{combat_exp: 0}

      # pow(0, 1/3) = 0, floor = 0, + 1 = 1
      assert Stats.query_level(stats) == 1
    end
  end
end
