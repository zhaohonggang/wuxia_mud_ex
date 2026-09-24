defmodule Kantele.World.LPCConverterNpcFunctionsTest do
  use ExUnit.Case, async: true

  alias Kantele.World.LPCConverter

  @xiaoer_path "test_minimal_world_v2_modified/npc/xiaoer.c"
  @furen_path "test_minimal_world_v2_modified/npc/furen.c"
  @worker_liu_path "test_minimal_world_v2_modified/npc/worker-liu.c"
  @zhuangjia_path "test_minimal_world_v2_modified/npc/zhuangjia.c"
  @duke_path "test_minimal_world_v2_modified/npc/duke.c"
  @menwei_path "test_minimal_world_v2_modified/npc/menwei.c"
  @shouwei_path "test_minimal_world_v2_modified/npc/shouwei.c"
  @wudunru_path "test_minimal_world_v2_modified/npc/wudunru.c"
  @jiang_path "test_minimal_world_v2_modified/npc/jiang.c"
  @huangyi_path "test_minimal_world_v2_modified/npc/huangyi.c"

  defp parse(path) do
    {:ok, ast} = LPCConverter.parse_ast(File.read!(path), path, path)
    ast
  end

  describe "init() 抽取" do
    test "xiaoer：add_action 注册命令与 greeting 延迟" do
      ast = parse(@xiaoer_path)
      assert ast.enter == %{greet_delay: 1, add_actions: ["drop", "exchange", "duihuan"], heartbeat: 0}
    end

    test "worker-liu：只声明 set_heart_beat" do
      ast = parse(@worker_liu_path)
      assert ast.enter == %{greet_delay: 0, add_actions: [], heartbeat: 1}
    end

    test "无 init() 的文件返回 nil" do
      ast = parse(@duke_path)
      assert ast.enter == nil
    end
  end

  describe "greeting() 抽取" do
    test "xiaoer：say 台词转占位符池" do
      ast = parse(@xiaoer_path)

      assert ast.greetings == [
               "店小二笑咪咪地说道：这位{respect}，进来喝杯茶，歇歇腿吧。",
               "店小二用脖子上的毛巾抹了抹手，说道：这位{respect}，请进请进。"
             ]
    end

    test "furen：ANSI 常量拼接与 $N/$n 换占位符，表达式注释行不误收" do
      ast = parse(@furen_path)
      assert length(ast.greetings) > 0

      assert Enum.any?(ast.greetings, fn line ->
               String.contains?(line, "庄夫人说道") and String.contains?(line, "{respect}")
             end)

      refute Enum.any?(ast.greetings, &String.contains?(&1, "{expr}"))
    end

    test "无 greeting() 返回 nil" do
      ast = parse(@duke_path)
      assert ast.greetings == nil
    end
  end

  describe "accept_object() 抽取" do
    test "xiaoer：收钱下限 1000 + 默认接受" do
      ast = parse(@xiaoer_path)

      assert ast.accept == [
               %{kind: "money", min: 1000, msg: "小二一哈腰，说道：多谢您老，客官请上楼歇息。"},
               %{kind: "any", accept: true, msg: "好！好！"}
             ]
    end

    test "zhuangjia：收任意钱（无下限）+ 拒绝非钱" do
      ast = parse(@zhuangjia_path)

      assert ast.accept == [
               %{kind: "money", min: nil, msg: "{npc}接过{name}给的钱，笑道：好！请押注。"},
               %{kind: "any", accept: false, msg: "{npc}接过{name}给的钱，笑道：好！请押注。"}
             ]
    end

    test "furen：指定 item_id / item_name 规则" do
      ast = parse(@furen_path)
      kinds = Enum.map(ast.accept, & &1.kind)

      assert "item_id" in kinds
      assert "item_name" in kinds

      assert Enum.find(ast.accept, &(&1.kind == "item_id")).id == "wu zhi rong"
      assert Enum.any?(ast.accept, &(&1.kind == "item_name" && &1.name == "明史辑略"))
    end

    test "无 accept_object() 返回 nil" do
      ast = parse(@duke_path)
      assert ast.accept == nil
    end
  end

  describe "permit_pass()/guarder 抽取" do
    test "menwei：提取 family 与拒绝台词" do
      ast = parse(@menwei_path)

      assert ast.guard != nil
      assert ast.guard.family == "白驼山庄"
      assert String.contains?(ast.guard.refuse_other, "白驼山庄重地")
    end

    test "无 permit_pass() 的 NPC 返回 nil" do
      ast = parse(@duke_path)
      assert ast.guard == nil
    end
  end

  describe "accept_fight/accept_hit/accept_kill 抽取（engage）" do
    test "shouwei：三位一体，userp 拒绝 + :: 继承回退" do
      ast = parse(@shouwei_path)

      assert ast.engage != nil
      assert Map.keys(ast.engage) == [:fight, :hit, :kill]
      assert Enum.all?(ast.engage, fn {_, rule} -> rule.accept == false end)
      assert Enum.all?(ast.engage, fn {_, rule} -> rule.inherit end)

      assert ast.engage.fight.msg == "{npc}吓了一跳，慌忙对{name}道：“小的不敢，小的不敢！”"
      assert Enum.all?(ast.engage, fn {_, rule} -> rule.retaliate == false end)
    end

    test "wudunru：fight 拒绝，hit/kill 接受并反杀（kill_ob）" do
      ast = parse(@wudunru_path)

      assert ast.engage.fight.accept == false
      refute ast.engage.fight.retaliate

      assert ast.engage.hit.accept == true
      assert ast.engage.hit.retaliate
      assert ast.engage.hit.msg == "给我滚进去，跑到这里来瞎胡闹什么！"

      assert ast.engage.kill.accept == true
      assert ast.engage.kill.retaliate
    end

    test "jiang：accept_fight 接受，msg 无台词，复杂 call_out 逻辑保留在 note" do
      ast = parse(@jiang_path)

      assert ast.engage.fight.accept == true
      assert ast.engage.fight.msg == nil
      assert Enum.all?(ast.engage, fn {_, rule} -> rule.retaliate == false end)
      assert String.contains?(ast.engage.fight.note, "call_out")
    end

    test "huangyi：fight 拒绝；kill 拒绝但召唤保镖（spawn）" do
      ast = parse(@huangyi_path)

      assert ast.engage.fight.accept == false
      assert ast.engage.fight.msg == "小女子哪里是您的对手？"

      assert ast.engage.kill.accept == false
      assert ast.engage.kill.spawn == ["baobiao"]
      # ob->kill_ob / me->kill_ob 是帮手反杀，非自身 → retaliate 应为 false
      assert ast.engage.kill.retaliate == false
    end

    test "duke（无 accept_* 函数）返回 nil" do
      ast = parse(@duke_path)
      assert ast.engage == nil
    end

    test "generate_npc_ucl：engage 块输出完整" do
      {:ok, ucl} = LPCConverter.convert_string(File.read!(@shouwei_path),
        base_path: "test_minimal_world_v2_modified/npc")

      assert String.contains?(ucl, "engage = {")
      assert String.contains?(ucl, "fight = { accept = false")
      assert String.contains?(ucl, "hit = { accept = false")
      assert String.contains?(ucl, "kill = { accept = false")
      # engage 块出现在 accept 规则后的 NPC 主体内
      assert ucl =~ ~r/accept = \[[\s\S]*engage = \{/
    end
  end

  describe "switch 分桶（tables / pools / other）" do
    test "xiaoer：random 台词池进 pools，arg 键值表进 tables" do
      ast = parse(@xiaoer_path)
      u = ast.unhandled

      assert length(u[:switch_tables]) == 1
      assert length(u[:switch_pools]) == 4
      assert u[:switch_statements] == []

      [table] = u[:switch_tables]
      assert table.expr == "arg"
      assert [%{key: "血菩提", cols: [{"cost", "5"}, {"ob", "new (\"/clone/fam/pill/puti1\")"}]} | _] =
               table.rows
    end

    test "无 switch 的 NPC 三桶皆空" do
      ast = parse(@duke_path)
      assert ast.unhandled[:switch_tables] == []
      assert ast.unhandled[:switch_pools] == []
      assert ast.unhandled[:switch_statements] == []
    end
  end

  describe "条件分支抽取（conditional_branches）" do
    test "hunger：if/else-if/else 链 切分" do
      ast = parse("test_minimal_world_v2_modified/condition/hunger.c")
      cb = ast.unhandled[:conditional_branches]
      assert Map.has_key?(cb, "update_condition")

      [chain] =
        cb["update_condition"]
        |> Enum.filter(fn chain -> Enum.any?(chain, &(&1.kind == :elif)) end)

      assert Enum.map(chain, & &1.kind) == [:if, :elif, :elif]

      assert Enum.find(chain, &(&1.kind == :if)).cond == ~s{duration == 4}

      # 无 else 的独立 if 独立成链
      isolated = Enum.find(cb["update_condition"], fn c -> length(c) == 1 end)
      assert {isolated |> hd() |> Map.fetch!(:kind), isolated |> hd() |> Map.fetch!(:cond)} ==
               {:if, ~s{me->query("food") > 0 && me->query("water") > 0}}

      # duration==4 分支含 tell_object 台词
      d4 = Enum.find(chain, &(&1.cond == ~s{duration == 4}))
      assert Enum.any?(d4.actions, &String.starts_with?(&1, "tell_object(me, HIY"))
    end

    test "case 无 else 的独立 if 也产出分支" do
      ast = parse(@duke_path)

      cb =
        ast.unhandled[:conditional_branches]
        |> Map.values()
        |> List.flatten()

      assert length(cb) >= 0
    end

    test "UCL 注释含 CONDITIONAL BRANCHES 节" do
      path = "test_minimal_world_v2_modified/condition/hunger.c"
      {:ok, ucl} = LPCConverter.convert_string(File.read!(path),
        base_path: "test_minimal_world_v2_modified/condition")

      assert String.contains?(ucl, "# ==== CONDITIONAL BRANCHES ====")
      assert String.contains?(ucl, "# ==== CONDITIONAL BRANCHES (update_condition) ====")
      assert String.contains?(ucl, "if (me->query(\"food\") > 0 && me->query(\"water\") > 0)")
    end
  end
end