defmodule Kantele.Character.SpecialSkillsTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.SpecialSkills

  @dummy Kantele.Character.SpecialSkills.DaemonDummy

  defmodule DaemonDummy do
    @moduledoc "测试注入的假特技模块（绝不落盘到真实读取点）"
    def title, do: "灵犀指"
    def perform(conn, _opts), do: conn
  end

  test "空库起步：无任何特技" do
    assert SpecialSkills.all() == %{}
    assert SpecialSkills.daemon("piyi") == :error
    refute SpecialSkills.registered?("piyi")
  end

  test "register/2 热增后可解析（注入宿主形状 attributes[\"special_skills\"]）" do
    on_exit(fn -> SpecialSkills.unregister("piyi") end)
    assert :ok = SpecialSkills.register("piyi", @dummy)

    assert SpecialSkills.registered?("piyi")
    assert {:ok, @dummy} = SpecialSkills.daemon("piyi")
    assert SpecialSkills.all()["piyi"] == @dummy
  end

  test "unregister/1 热删" do
    SpecialSkills.register("greedy", @dummy)
    assert SpecialSkills.registered?("greedy")
    :ok = SpecialSkills.unregister("greedy")
    refute SpecialSkills.registered?("greedy")
    assert SpecialSkills.daemon("greedy") == :error
  end

  describe "owned?/immune?（统一宿主形状 attributes[\"special_skills\"]）" do
    test "主形状：字符串 map 值 true" do
      assert SpecialSkills.owned?(%{"special_skills" => %{"piyi" => true}}, "piyi")
      assert SpecialSkills.immune?(%{"special_skills" => %{"piyi" => true}}, "piyi")
      refute SpecialSkills.owned?(%{"special_skills" => %{"piyi" => false}}, "piyi")
    end

    test "condition 引擎 state 用原子键 special_skills（tick 构造）" do
      attrs = %{jing: 2000, qi: 5000, special_skills: %{"piyi" => true}}
      assert SpecialSkills.immune?(attrs, "piyi")
    end

    test "兼容旧旗标 special_skill/<id>（attributes.ex 曾用）" do
      assert SpecialSkills.owned?(%{"special_skill/youth" => true}, "youth")
    end

    test "缺失/非 map 一律 false" do
      refute SpecialSkills.owned?(%{}, "piyi")
      refute SpecialSkills.owned?(%{"special_skills" => %{}}, "piyi")
      refute SpecialSkills.owned?(nil, "piyi")
    end
  end
end
