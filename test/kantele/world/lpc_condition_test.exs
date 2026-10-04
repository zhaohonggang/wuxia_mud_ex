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

  describe "对真实结构体 meta 求值（回归）" do
    # 之前所有用例的 meta 都是**普通 map**，而线上的 meta 是结构体
    # （%PlayerMeta{} / %NonPlayerMeta{}）。结构体没实现 Access 协议，
    # 于是 get_in(meta, [:stats, :skills]) 抛
    # "Kalevala.Meta.Trimmed.fetch/2 is undefined"，异常被 rescue 静默转成放行，
    # 线上表现为「孟婆桥明明该拦，却能走过去」。这里用真结构体钉住。
    test "PlayerMeta 结构体上 query_skill / query_temp 正常求值" do
      meta = %Kantele.Character.PlayerMeta{
        vitals: %{},
        stats: %Kantele.Character.Stats{skills: %{"force" => 20}},
        temp: %{}
      }

      me = %{pid: self(), name: "测试玩家", meta: meta}

      ctx =
        Kantele.World.ExitVetoContext.build(
          dir: "north",
          me: me,
          room: %{exits: []},
          context: %{characters: []}
        )

      assert {:ok, true} =
               Kantele.World.LpcCondition.evaluate("(int)me->query_skill('force') < 500", ctx)

      assert {:ok, false} =
               Kantele.World.LpcCondition.evaluate("(int)me->query_skill('force') > 500", ctx)

      assert {:ok, true} =
               Kantele.World.LpcCondition.evaluate("!me->query_temp('rent_paid')", ctx)
    end

    test "NonPlayerMeta 结构体上 query_skill 正常求值；NPC 无 temp 字段故 query_temp 为假" do
      meta = %Kantele.Character.NonPlayerMeta{
        vitals: %{},
        stats: %Kantele.Character.Stats{skills: %{"force" => 700}}
      }

      ctx =
        Kantele.World.ExitVetoContext.build(
          dir: "south",
          me: %{pid: self(), name: "npc", meta: meta},
          room: %{exits: []},
          context: %{characters: []}
        )

      assert {:ok, false} =
               Kantele.World.LpcCondition.evaluate("(int)me->query_skill('force') < 500", ctx)

      # NPC 结构体里没有 temp 字段，LPC 侧 query_temp 对 NPC 恒为 0
      assert {:ok, false} = Kantele.World.LpcCondition.evaluate("me->query_temp('guarded')", ctx)
    end

    @tag :world_data
    test "孟婆桥：真实结构体 meta + 真实在场角色 -> 拦下" do
      world = Kantele.World.Loader.load()
      room = Enum.find(world.rooms, &(&1.id == "death:qiao1"))
      veto = Enum.find(room.exit_vetoes, &(&1.condition =~ "mengpo_tang"))

      assert veto, "应有孟婆桥的条件"

      mengpo = %{
        name: "孟婆",
        pid: self(),
        meta: %Kantele.Character.NonPlayerMeta{
          vitals: %{},
          aliases: ["meng po", "meng", "po"]
        }
      }

      me = %{
        pid: self(),
        name: "测试玩家",
        meta: %Kantele.Character.PlayerMeta{
          vitals: %{},
          stats: %Kantele.Character.Stats{skills: %{"force" => 20}},
          temp: %{}
        }
      }

      ctx =
        Kantele.World.ExitVetoContext.build(
          dir: "north",
          me: me,
          room: room,
          context: %{characters: [mengpo], item_instances: []}
        )

      assert {:block, msg} = Kantele.World.LpcCondition.check(veto, ctx)
      assert msg =~ "孟婆"
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
    test "灰度开关已开启" do
      assert Application.get_env(:ex_venture, :enforce_exit_vetoes, false) == true
    end
  end

  describe "direction_scoped?/1" do
    test "提到 dir 即视为方向限定" do
      assert Cond.direction_scoped?("dir == 'east' && objectp(present('shi wei',environment(me)))")
      assert Cond.direction_scoped?("dir != \"north\"")
    end

    test "不提 dir 即为「所有方向都拦」——必须被识别出来" do
      # 这类来自转换器丢了外层 `if (dir != "east")` 守卫的情形
      refute Cond.direction_scoped?("(int)me->query_skill('force') < 100")
      refute Cond.direction_scoped?("me->query_temp('rent_paid')")
      refute Cond.direction_scoped?("objectp(present('niu tou',environment(me)))")
    end
  end

  describe "supported?/1" do
    test "依赖玩家性别的条件**现在**可执行（gender 已落地）" do
      # character_metadata.gender 有列、默认值「男性」，apply_to_character 会写进
      # meta.env[:gender]。此前这里曾是 refute —— 正是那个「恒真 -> 永久拦死玩家」
      # 的守卫把它整批挡下的。
      assert Cond.supported?("me->query('gender') != '男性' && dir == 'in'")
      assert Cond.supported?("(string)me->query(\"gender\") == '女性'")
    end

    test "不依赖缺失数据的条件照常执行" do
      assert Cond.supported?("dir == 'east' && objectp(present('shi wei',environment(me)))")
      assert Cond.supported?("!me->query_temp('rent_paid') && dir == 'up'")
    end

    @tag :world_data
    test "数据里已没有「依赖缺失字段而被守卫排除」的条件" do
      world = Kantele.World.Loader.load()

      conds =
        Enum.flat_map(world.rooms, fn r -> Enum.map(r.exit_vetoes || [], &{r.id, &1}) end)
        |> Enum.filter(fn {_id, v} -> is_binary(Map.get(v, :condition)) end)
        |> Enum.filter(fn {_id, v} -> Cond.direction_scoped?(v.condition) end)
        |> Enum.filter(fn {_id, v} -> not Cond.supported?(v.condition) end)
        |> Enum.map(fn {id, v} -> {id, v.condition} end)

      # 曾经这里是 9 条依赖 gender 的条件。因为 `me->query("gender")` 恒为 nil，
      # `!= '男性'` / `!= '女性'` 会恒真，把 mingjiao 门、xiangyang 聚义花园这类
      # 地方永久拦住 —— 所以当时整批挡下。现在 gender 落地了，这一类归零。
      assert conds == [],
             "不应再有被 supported? 排除的条件，实际 #{inspect(conds)}"
    end

    @tag :world_data
    test "11 条 gender 条件现在全部 supported 且可执行" do
      world = Kantele.World.Loader.load()

      conds =
        Enum.flat_map(world.rooms, fn r ->
          Enum.map(r.exit_vetoes || [], fn v -> Map.get(v, :condition) end)
        end)
        |> Enum.filter(fn c -> is_binary(c) and String.contains?(c, "gender") end)

      assert length(conds) == 11, "预期 11 条 gender 条件，实际 #{length(conds)}"
      assert Enum.all?(conds, &Cond.supported?/1)
    end
  end

  @tag :world_data
  test "数据里方向未限定的条件不会被执行（防锁死）" do
    world = Kantele.World.Loader.load()

    conds =
      Enum.flat_map(world.rooms, fn r -> Enum.map(r.exit_vetoes || [], &{r.id, &1}) end)
      |> Enum.filter(fn {_id, v} -> is_binary(Map.get(v, :condition)) end)

    unscoped = Enum.filter(conds, fn {_id, v} -> not Cond.direction_scoped?(v.condition) end)

    # 这批暂不执行；补齐外层守卫后应逐步下降（见 scripts/audit_exit_veto_locks.py）
    assert length(unscoped) > 0
    assert length(unscoped) < length(conds)
  end

  describe "satisfiable?/2 —— 析取不能当合判" do
    test "present_refs/1 取别名（带空格、单双引号都行）" do
      assert Cond.present_refs("objectp(present('liu chuxuan', environment(me)))") ==
               ["liu chuxuan"]

      assert Cond.present_refs(~s|objectp(present("shi wei", environment(me)))|) ==
               ["shi wei"]

      assert Cond.present_refs("me->query('gender') == '女性'") == []
    end

    test "析取：有一条分支成立就算可能生效" do
      # 这是 shaolin/qyping 的真实条件：fumo dao 在 LPC 里根本不存在
      # （只有伏魔杖/伏魔剑/大伏魔拳），但 jingang zhao 有定义，
      # 所以这条门禁**一直是有效的**——早先一律当合判把它误报成 dead。
      expr =
        "(present('fumo dao',me) || present('jingang zhao',me) || " <>
          "present('fumo dao',environment(me)) || present('jingang zhao',environment(me))) " <>
          "&& dir == 'in'"

      refute Cond.satisfiable?(expr, %{"fumo dao" => false, "jingang zhao" => true}) ==
               false

      refute Cond.satisfiable?(expr, %{"fumo dao" => false, "jingang zhao" => false})
    end

    test "合取：全都得成立" do
      expr = "present('a', environment(me)) && present('b', environment(me))"

      assert Cond.satisfiable?(expr, %{"a" => true, "b" => true})
      refute Cond.satisfiable?(expr, %{"a" => true, "b" => false})
      refute Cond.satisfiable?(expr, %{"a" => false, "b" => true})
    end

    test "mingjiao/square：五个 NPC 的析取，有任一个在场就有效" do
      expr =
        "me->query('family/family_name') != '明教' && (dir!='south') && " <>
          "((objectp(present('peng yinyu',environment(me)))) || " <>
          "(objectp(present('zhang zhong',environment(me)))) || " <>
          "(objectp(present('shuo bude',environment(me)))) || " <>
          "(objectp(present('leng qian',environment(me)))) || " <>
          "(objectp(present('zhou dian',environment(me)))))"

      assert Cond.satisfiable?(expr, %{"shuo bude" => true})
      assert Cond.satisfiable?(expr, %{"leng qian" => true})

      refute Cond.satisfiable?(expr, %{
               "peng yinyu" => false,
               "zhang zhong" => false,
               "shuo bude" => false,
               "leng qian" => false,
               "zhou dian" => false
             })
    end

    test "! 只作用在 present() 上才取反，!wizardp(me) 不能被翻成 false" do
      # `!wizardp(me)` 我们无法预知，乐观取 true；
      # 若按「先乐观成 true 再取反」会得到 false，等于凭空断言这条永远不拦。
      expr = "!wizardp(me) && objectp(present('guan jia',environment(me)))"

      assert Cond.satisfiable?(expr, %{"guan jia" => true})
      refute Cond.satisfiable?(expr, %{"guan jia" => false})

      # 但 !present(...) 是货真价实的取反
      assert Cond.satisfiable?("!present('a', me)", %{"a" => false})
      refute Cond.satisfiable?("!present('a', me)", %{"a" => true})
    end
  end

  # ---- 集成：用真实世界数据复现线上场景 ----

  describe "真实数据集成" do
    @tag :world_data
    test "康府大门：侍卫在场时禁止向东，提示为 LPC 原文" do
      {room, occupants} = kangfu_men()

      veto = Enum.find(room.exit_vetoes, &(Map.get(&1, :direction) == "east"))
      assert veto, "kangfu_men 应有向东的阻挡条件"
      assert Cond.enforceable?(veto.condition)

      npc_ctx =
        Kantele.World.ExitVetoContext.build(
          dir: "east",
          me: nil,
          room: room,
          context: %{characters: occupants}
        )

      # 房里确实有康府侍卫，且带 "shi wei" 别名
      assert Enum.any?(occupants, &(to_string(&1.name) =~ "侍卫"))

      assert Enum.any?(occupants, fn c ->
               Enum.member?(Map.get(c.meta, :aliases) || [], "shi wei")
             end)

      assert {:block, msg} = Cond.check(veto, npc_ctx)
      assert msg =~ "康府侍卫"

      # 换方向不受影响
      other =
        Kantele.World.ExitVetoContext.build(
          dir: "west",
          me: nil,
          room: room,
          context: %{characters: occupants}
        )

      assert :allow = Cond.check(veto, other)
    end

    @tag :world_data
    test "房里没有侍卫时放行（条件为假）" do
      {room, _occupants} = kangfu_men()
      veto = Enum.find(room.exit_vetoes, &(Map.get(&1, :direction) == "east"))

      empty_ctx =
        Kantele.World.ExitVetoContext.build(
          dir: "east",
          me: nil,
          room: room,
          context: %{characters: []}
        )

      assert :allow = Cond.check(veto, empty_ctx)
    end
  end

  defp kangfu_men do
    world = Kantele.World.Loader.load()

    room = Enum.find(world.rooms, &(&1.id == "beijing:kangfu_men"))
    occupants = Enum.filter(world.characters, &(&1.room_id == "beijing:kangfu_men"))
    {room, occupants}
  end
end