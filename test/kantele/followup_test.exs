defmodule Kantele.Util.TreeMapTest do
  use ExUnit.Case, async: true

  alias Kantele.Util.TreeMap

  describe "query (treemap _query)" do
    test "命中标量/嵌套" do
      m = %{a: %{b: %{c: 42}}}
      assert TreeMap.query(m, [:a, :b, :c]) == 42
      assert TreeMap.query(m, [:a, :b]) == %{c: 42}
    end

    test "中途遇到非 map 返回该值" do
      m = %{a: 7}
      assert TreeMap.query(m, [:a, :b]) == 7
    end

    test "路径缺失返回 nil / 空路径 nil" do
      m = %{a: %{b: 1}}
      assert TreeMap.query(m, [:a, :z, :q]) == nil
      assert TreeMap.query(m, []) == nil
    end
  end

  describe "set (treemap _set, 自动建中间 map)" do
    test "写入/覆盖标量" do
      assert TreeMap.set(%{}, [:a], 1) == %{a: 1}
      assert TreeMap.set(%{a: 1}, [:a], 2) == %{a: 2}
    end

    test "自动创建中间 map" do
      m = TreeMap.set(%{}, [:a, :b, :c], 9)
      assert m == %{a: %{b: %{c: 9}}}
    end

    test "走查中间已存在的 map" do
      m = TreeMap.set(%{a: %{x: 1}}, [:a, :b], 2)
      assert m == %{a: %{b: 2, x: 1}}
    end
  end

  describe "delete (treemap _delete)" do
    test "删末段" do
      {m, true} = TreeMap.delete(%{a: %{b: 1}}, [:a, :b])
      assert m == %{a: %{}}
    end

    test "中间非 map 无法删" do
      {m, false} = TreeMap.delete(%{a: 7}, [:a, :b])
      assert m == %{a: 7}
    end
  end
end

defmodule Kantele.Character.NameTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Name

  describe "set_name / compose_name" do
    test "surname+purename 组名" do
      assert Name.set_name(%{surname: "张", purename: "三丰"}, "", ["zhang"]) ==
               %{my_id: ["zhang"], name: "张三丰", id: "zhang"}
    end

    test "缺省无名氏" do
      assert Name.compose_name(%{surname: "", purename: ""}) == "无名氏"
      assert Name.compose_name("", "") == "无名氏"
    end

    test "非玩家追加首字母小写 ID" do
      assert Name.lowercase_first(["Changjian"], false) == ["Changjian", "c"]
      assert Name.lowercase_first(["player"], true) == ["player"]
    end
  end

  describe "id? / parse_command_id_list" do
    test "id 命中" do
      obj = %{my_id: ["changjian", "c"]}
      assert Name.id?(obj, "changjian")
      assert Name.id?(obj, "c")
      refute Name.id?(obj, "nope")
    end

    test "parse_command_id_list applied 优先" do
      obj = %{my_id: ["a", "c"]}
      assert Name.parse_command_id_list(obj, ["apply"]) == ["apply"]
      assert Name.parse_command_id_list(obj, []) == ["a", "c"]
    end
  end

  describe "render_name / render_short" do
    test "短名 name + (id)" do
      assert Name.render_short(%{name: "张三", id: "zhangsan"}) == "张三(Zhangsan)"
    end
  end
end

defmodule Kantele.Character.TeamFollowTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Team

  @team %{
    id: "t1",
    leader_id: "leader",
    members: [
      %{id: "leader", pid: :p_leader, name: "L"},
      %{id: "m1", pid: :p1, name: "M1"}
    ]
  }

  describe "follow? (team.c follow_me)" do
    test "跟随 leader" do
      assert Team.follow?(@team, "leader") == {:follow, :leader}
    end

    test "no_follow + 身法落后则不跟随" do
      # leader dex 远高 → 必 outrun → :no_follow（确定性）
      opts = %{no_follow: true, dex: 1, leader_dex: 100}
      assert Team.follow?(@team, "leader", opts) == :no_follow
    end

    test "跟随队伍领袖(首位)" do
      # 首位仍指 leader（成员[0]），非首位 m1 不跟随
      assert Team.follow?(@team, "m1") == :no_follow
    end

    test "无关对象不跟随" do
      assert Team.follow?(@team, "stranger") == :no_follow
    end
  end
end
