defmodule Kantele.World.LpcConditionTest do
  use ExUnit.Case, async: true

  alias Kantele.World.LpcCondition, as: Cond

  # ---- 词法/语法：覆盖真实语料里的各种写法 ----

  describe "parse/1" do
    test "方向比较" do
      assert {:ok, {:cmp, "==", {:var, "dir"}, {:str, "north"}}} =
               Cond.parse("dir == \"north\"")
    end

    test "无空格也能切" do
      assert {:ok, {:cmp, "==", {:var, "dir"}, {:str, "down"}}} = Cond.parse("dir==\"down\"")
    end

    test "present + environment 嵌套调用" do
      assert {:ok, _} = Cond.parse("objectp(present(\"shi wei\", environment(me)))")
    end

    test "方法调用与类型转换" do
      assert {:ok, {:cmp, "<", {:cast, "int", {:call, _, _}}, {:num, 600}}} =
               Cond.parse("(int)me->query(\"combat_exp\") < 600")
    end

    test "赋值 + 后续引用" do
      assert {:ok, _} =
               Cond.parse("objectp(ob = present(\"ao bai\", environment(me))) && living(ob) && dir == \"north\"")
    end

    test "单引号字面量（数据侧的实际存法）" do
      assert {:ok, {:cmp, "==", {:var, "dir"}, {:str, "in"}}} = Cond.parse("dir == 'in'")
    end

    test "取反与括号" do
      assert {:ok, _} = Cond.parse("! me->query_temp(\"marks/x\") && (dir == \"up\" || dir == \"down\")")
    end
  end

  describe "enforceable?/1" do
    test "支持形态可执行" do
      assert Cond.enforceable?("dir == \"north\" && objectp(present(\"shi wei\", environment(me)))")
      assert Cond.enforceable?("(int)me->query_skill(\"force\") < 100")
      assert Cond.enforceable?("!me->query_temp(\"rent_paid\") && dir == \"up\"")
    end

    test "不支持的形态明确拒绝（数组下标 / 映射取键）" do
      refute Cond.enforceable?("(int)inv[i]->query(\"weapon_prop\")")
      refute Cond.enforceable?("!myfam || myfam[\"family_name\"] != \"星宿派\"")
    end

    test "自定义函数不支持" do
      refute Cond.enforceable?("check_dirs(me, dir)")
      refute Cond.enforceable?("ob->refuse(me)")
    end
  end

  describe "evaluate/2" do
    setup do
      npc = %{name: "守卫", pid: self(), meta: %{}}

      ctx = %{
        dir: "north",
        me: %{pid: self(), meta: %{temp: %{"rent_paid" => true}, env: %{}, stats: %{skills: %{}}}},
        room: %{id: "test:room", exits: []},
        vars: %{},
        resolver: %{
          present: fn
            "守卫", _scope -> {:ok, npc}
            _, _ -> :error
          end,
          environment: fn _ -> {:ok, %{id: "test:room", exits: []}} end,
          living: fn _ -> true end,
          wizardp: fn _ -> false end,
          userp: fn _ -> true end,
          id: fn %{id: id} -> id end,
          call: fn
            _target, "query_temp", ["rent_paid"] -> {:ok, true}
            _target, "query_temp", _ -> {:ok, nil}
            _target, "query_skill", [_] -> {:ok, 30}
            _target, _method, _args -> :error
          end
        }
      }

      %{ctx: ctx}
    end

    test "dir 不匹配 -> 假", %{ctx: ctx} do
      assert {:ok, false} = Cond.evaluate("dir == \"north\" && objectp(present(\"守卫\", environment(me)))", %{ctx | dir: "south"})
    end

    test "房里有人且方向对 -> 真", %{ctx: ctx} do
      assert {:ok, true} = Cond.evaluate("dir == 'north' && objectp(present('守卫',environment(me)))", ctx)
    end

    test "房里没人 -> 假", %{ctx: ctx} do
      assert {:ok, false} = Cond.evaluate("dir == 'north' && objectp(present('不存在',environment(me)))", ctx)
    end

    test "query_temp 真假", %{ctx: ctx} do
      assert {:ok, true} = Cond.evaluate("me->query_temp('rent_paid')", ctx)
      assert {:ok, false} = Cond.evaluate("me->query_temp('没有这个键')", ctx)
    end

    test "query_skill 数值比较", %{ctx: ctx} do
      assert {:ok, true} = Cond.evaluate("(int)me->query_skill('force') < 100", ctx)
      assert {:ok, false} = Cond.evaluate("(int)me->query_skill('force') > 100", ctx)
    end

    test "赋值 + living", %{ctx: ctx} do
      expr = "objectp(ob = present('守卫',environment(me))) && living(ob) && dir == 'north'"
      assert {:ok, true} = Cond.evaluate(expr, ctx)
    end

    test "字符串比较用值语义（缺属性视为空串）", %{ctx: ctx} do
      assert {:ok, true} = Cond.evaluate("(string)me->query('gender') != '男性'", ctx)
    end

    test "求值器缺构件时不抛异常（按 0 处理，与 LPC「查不到即 0」一致）" do
      assert {:ok, _} = Cond.evaluate("me->query_skill('force') < 100", %{dir: "n", resolver: %{}})
    end
  end

  describe "check/2" do
    test "命中 -> {:block, message}" do
      veto = %{direction: "north", condition: "dir == 'north'", message: "过不去。"}
      ctx = %{dir: "north", me: nil, room: nil, resolver: %{}}

      assert {:block, "过不去。"} = Cond.check(veto, ctx)
    end

    test "未命中 -> :allow" do
      veto = %{direction: "north", condition: "dir == 'north'", message: "过不去。"}
      ctx = %{dir: "south", me: nil, room: nil, resolver: %{}}

      assert :allow = Cond.check(veto, ctx)
    end

    test "条件不可执行 -> 放行（宁可少拦）" do
      veto = %{direction: "north", condition: "(int)inv[i]->query('weapon_prop')", message: "x"}
      ctx = %{dir: "north", me: nil, room: nil, resolver: %{}}

      assert :allow = Cond.check(veto, ctx)
    end

    test "无 condition -> 放行" do
      assert :allow = Cond.check(%{direction: "north", message: "x"}, %{dir: "north"})
    end
  end

  describe "数据侧" do
    @tag :world_data
    test "valid_leave 条件已从注释搬进 condition，绝大多数可执行" do
      world = Kantele.World.Loader.load()

      {with_cond, without_cond} =
        Enum.flat_map(world.rooms, fn r -> Enum.map(r.exit_vetoes || [], &{r.id, &1}) end)
        |> Enum.split_with(fn {_id, v} -> is_binary(Map.get(v, :condition)) end)

      assert length(with_cond) > 150,
             "期望 160+ 条阻挡条件已迁入 condition，实际 #{length(with_cond)}"

      enforceable = Enum.filter(with_cond, fn {_id, v} -> Cond.enforceable?(v.condition) end)

      # 166 条里 148 条可执行；剩下 18 条是三种自定义函数形态
      # （check_dirs 8 / check_out 5 / ob->refuse 5），保留原文、运行时放行
      assert length(with_cond) == 166
      assert length(enforceable) == 148

      unsupported = Enum.reject(with_cond, fn {_id, v} -> Cond.enforceable?(v.condition) end)

      shapes = unsupported |> Enum.map(fn {_id, v} -> v.condition end) |> Enum.uniq() |> Enum.sort()

      assert shapes == ["check_dirs(me,dir)", "check_out(me)", "ob->refuse(me)"]

      # 无 condition 的条目只剩 message（原 LPC 本来就无条件），仍应保留提示文本
      assert length(without_cond) > 0
      assert Enum.all?(without_cond, fn {_id, v} -> is_binary(Map.get(v, :message)) end)
    end

    @tag :world_data
    test "开关默认关闭：阻挡条件不参与移动判定" do
      assert Application.get_env(:ex_venture, :enforce_exit_vetoes, false) == false
    end
  end
end