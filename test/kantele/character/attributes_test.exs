defmodule Kantele.Character.AttributesTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Attributes

  defp stats_overrides(overrides) do
    Map.merge(
      %{skills: %{"unarmed" => 60, "force" => 20, "dodge" => 60, "parry" => 60, "literate" => 0}},
      overrides
    )
  end

  test "str: base + max(unarmed/cuff/...) /10 + apply" do
    opts = stats_overrides(%{skills: %{"unarmed" => 60, "cuff" => 100}, apply: %{"str" => 5}})
    assert Attributes.str(20, opts) == 20 + div(100, 10) + 5
  end

  test "str: 无技能表时只返回 base + apply" do
    assert Attributes.str(20, %{apply: %{"str" => 3}}) == 23
  end

  test "int: 由 literate/10 加成" do
    opts = stats_overrides(%{skills: %{"literate" => 40}})
    assert Attributes.int(20, opts) == 20 + div(40, 10)
  end

  test "con: 由 force/10 加成" do
    opts = stats_overrides(%{skills: %{"force" => 30}})
    assert Attributes.con(20, opts) == 20 + div(30, 10)
  end

  test "dex: 由 dodge/10 加成" do
    opts = stats_overrides(%{skills: %{"dodge" => 50}})
    assert Attributes.dex(20, opts) == 20 + div(50, 10)
  end

  test "per: 纹身 + apply + 年龄衰减" do
    # age 80 -> -6
    assert Attributes.per(20, %{age: 80}) == 14
    # age 35 -> -2
    assert Attributes.per(20, %{age: 35}) == 18
    # age <= 30 无衰减
    assert Attributes.per(20, %{age: 20}) == 20
    # tattoo + apply
    opts = %{age: 20}
    opts = Map.put(opts, "tattoo/per", 3)
    opts = Map.put(opts, :apply, %{"per" => 1})
    assert Attributes.per(20, opts) == 24
  end

  test "per: youth 特技无视年龄" do
    assert Attributes.per(20, %{age: 80, youth?: true}) == 20
    opts = %{age: 80}
    opts = Map.put(opts, "special_skill/youth", true)
    assert Attributes.per(20, opts) == 20
  end

  test "level: floor((combat_exp*10)^(1/3)) + 1" do
    assert Attributes.level(0) == 1
    # combat_exp=1000 -> (10000)^(1/3)=21.54 -> trunc 21 +1 = 22
    assert Attributes.level(1000) == 22
    # combat_exp=100 -> 1000^(1/3) 浮点=9.9999 -> trunc 9 +1 = 10 (与 LPC to_int 一致)
    assert Attributes.level(100) == 10
  end

  test "tattoo/reborn 加成" do
    opts = %{}
    opts = Map.put(opts, "tattoo/str", 4)
    opts = Map.put(opts, "reborn/str", 2)
    opts = Map.put(opts, :apply, %{"str" => 1})
    opts = Map.put(opts, :skills, %{})
    assert Attributes.str(20, opts) == 20 + 4 + 2 + div(0, 10) + 1
  end
end
