defmodule Kantele.Editor.LineTest do
  use ExUnit.Case, async: true

  alias Kantele.Editor.Line

  describe "accumulate (edit.c input_line)" do
    test "逐行累积" do
      s = Line.new(["第一行"])
      s = Line.accumulate(s, "第二行") |> elem(0)
      assert Line.accumulate(s, "第三行") == {%{lines: ["第一行", "第二行", "第三行"]}, :continue}
    end

    test "点结束并 join 文本" do
      s = Line.new(["a", "b"])
      assert Line.accumulate(s, ".") == {%{lines: ["a", "b"]}, {:done, "a\nb"}}
    end

    test "~q 取消" do
      assert Line.accumulate(Line.new(["a"]), "~q") == {%{lines: ["a"]}, :cancel}
    end

    test "~e 转 vi" do
      assert Line.accumulate(Line.new(), "~e") == {%{lines: []}, :use_vi}
    end
  end
end

defmodule Kantele.PagerTest do
  use ExUnit.Case, async: true

  alias Kantele.Pager

  describe "resolve (more_file 翻页解析)" do
    test "默认下页" do
      assert Pager.resolve("", 1, 100) == {:page, 1, 30}
    end

    test "q 离开" do
      assert Pager.resolve("q", 1, 100) == :quit
    end

    test "b 前两页 / t 回顶" do
      assert Pager.resolve("b", 100, 200) == {:page, 40, 30}
      assert Pager.resolve("t", 100, 200) == {:page, 1, 30}
    end

    test "数字跳行 / n 数字页长" do
      assert Pager.resolve("50", 1, 200) == {:page, 50, 30}
      assert Pager.resolve("n10", 1, 200) == {:page, 1, 10}
    end

    test "区间 a,b" do
      assert Pager.resolve("3,8", 1, 100) == {:page, 3, 6}
      # a>b 自动交换
      assert Pager.resolve("8,3", 1, 100) == {:page, 3, 6}
    end

    test "负行号从末尾倒数" do
      assert Pager.resolve("-5", 1, 200) == {:page, 195, 30}
    end

    test ">300 行钳制报错" do
      assert Pager.resolve("n302", 1, 500) == {:error, "连续显示的行数必须小于等于300。\n"}
    end

    test "at_end / progress" do
      assert Pager.at_end?(95, 30, 100)
      refute Pager.at_end?(1, 30, 100)
      assert Pager.progress_percent(1, 100) == 1
      assert Pager.progress_percent(50, 100) == 50
    end
  end
end

defmodule Kantele.ShellTest do
  use ExUnit.Case, async: true

  alias Kantele.Shell

  describe "变量存取 (shell.c vars)" do
    test "set/query/delete/count" do
      vars = Shell.set_var(%{}, "a", 1)
      vars = Shell.set_var(vars, "b", "x")
      assert Shell.query_var(vars, "a") == 1
      assert Shell.query_var_count(vars) == 2
      {vars, true} = Shell.delete_var(vars, "a")
      assert Shell.query_var(vars, "a") == nil
      assert Shell.query_var_count(vars) == 1
    end
  end

  describe "interpolate (shell.c parse_shell)" do
    test "替换 $...$ 对" do
      eval = fn inner -> "[" <> inner <> "]" end
      assert Shell.interpolate("a $x$ b $y$ c", eval) == "a [x] b [y] c"
    end

    test "无配对则原样" do
      assert Shell.interpolate("普通文本 $没有闭合", fn i -> i end) == "普通文本 $没有闭合"
    end
  end
end

defmodule Kantele.Protocol.GMCPTest do
  use ExUnit.Case, async: true

  alias Kantele.Protocol.GMCP

  describe "send_message (sendGMCP)" do
    test "模块点分 + json" do
      assert GMCP.send_message(%{"mud_name" => "Kantele"}, ["Core", "Hello"]) ==
               ~s(Core.Hello {"mud_name":"Kantele"})
    end

    test "无 data / 无模块返回 nil" do
      assert GMCP.send_message(%{}, []) == nil
      assert GMCP.send_message(:not_a_map, ["Core"]) == nil
    end
  end

  describe "char_vitals (Char.Vitals.Get)" do
    test "正常组装并 0 兜底" do
      v = %{qi: 100, max_qi: 200, jing: 30, max_jing: 50, potential: 200, learned_points: 50}
      d = GMCP.char_vitals(v)
      assert d["hp"] == 100
      assert d["max_hp"] == 200
      assert d["jing"] == 30
      assert d["pot"] == 150
      assert d["exp"] == 0
    end
  end

  describe "room_info (Room.Info.Get)" do
    test "name/exits/area/hash" do
      r = %{name: "\e[31m树林\e[0m", exits: ["east", "west"], file: "data/shanlin.c"}
      d = GMCP.room_info(r)
      assert d["name"] == "树林"
      assert d["exits"] == ["east", "west"]
      assert d["area"] == "shanlin.c"
      hash = :crypto.hash(:sha, r[:file] || "") |> Base.encode16(case: :lower)
      assert d["hash"] == hash
    end
  end

  describe "log (滚动日志)" do
    test "保留最近 50 条" do
      log = Enum.to_list(1..50)
      assert GMCP.log(log, "new") |> length() == 50
      assert List.last(GMCP.log(log, "new")) == "new"
    end
  end
end
