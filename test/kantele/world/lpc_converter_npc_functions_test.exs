defmodule Kantele.World.LPCConverterNpcFunctionsTest do
  use ExUnit.Case, async: true

  alias Kantele.World.LPCConverter

  @xiaoer_path "test_minimal_world_v2_modified/npc/xiaoer.c"
  @furen_path "test_minimal_world_v2_modified/npc/furen.c"
  @worker_liu_path "test_minimal_world_v2_modified/npc/worker-liu.c"
  @zhuangjia_path "test_minimal_world_v2_modified/npc/zhuangjia.c"
  @duke_path "test_minimal_world_v2_modified/npc/duke.c"
  @menwei_path "test_minimal_world_v2_modified/npc/menwei.c"

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
               %{kind: "money", min: 1000},
               %{kind: "any", accept: true}
             ]
    end

    test "zhuangjia：收任意钱（无下限）+ 默认接受" do
      ast = parse(@zhuangjia_path)

      assert ast.accept == [
               %{kind: "money", min: nil},
               %{kind: "any", accept: true}
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
end