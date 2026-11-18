defmodule Kantele.World.HuntingTest do
  @moduledoc """
      LPC `inherit/char/quarry.c::die()` / `inherit/char/snake.c::die()` 狩猎掉落概率门控单元测试。

      对齐 LPC 原式：

          random(skill) > 10          -> 主掉落 drop_a
          random(skill) > 60 && random(5) > 3  -> drop_c
          random(skill) > 30 && random(4) > 2  -> drop_b（与 drop_c 互斥）

      LPC `random(n)` 取值域为 [0, n-1]，`random(0)` 恒为 0。故 skill <= 11 时
      掷出最大值 10，`<= 10` 命中「不掉落」分支；skill >= 12 才可能掉落。

      `roll/3` 注入 `rng.(n)`（返回 [0, n-1]）以穷举边界，默认用 `lpc_rand/1`
      （`:rand.uniform/1 - 1`）。

      `roll/3` 返回的是**短物品引用**（如 "zhurou"），`resolve/1` 负责把短引用
      解析为 {完整缓存 key, 物品定义}。
  """

  use ExUnit.Case, async: false

  alias Kantele.World.Hunting
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @seq :hunting_test_seq

  # 按给定序列返回 LPC 风格骰子值 [0, n-1]；每次调用消耗一个值。
  # 所有调用都在当前 test 进程内同步执行，Process 字典安全。
  defp seq_rng(seq) do
    Process.put(@seq, seq)

    fn _n ->
      [v | rest] = Process.get(@seq)
      Process.put(@seq, rest)
      v
    end
  end

  defp item_def(name, unit \\ "块") do
    %Item{
      id: "clone_lib:" <> name,
      name: name,
      description: "测试物品 #{name}。",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{unit: unit}
    }
  end

  setup do
    Items.delete("clone_lib:zhurou")
    Items.delete("clone_lib:zhupi")
    Items.delete("clone_lib:xiongdan")

    Items.put("clone_lib:zhurou", item_def("野猪肉", "块"))
    Items.put("clone_lib:zhupi", item_def("猪皮", "张"))
    Items.put("clone_lib:xiongdan", item_def("熊胆", "个"))

    :ok
  end

  describe "roll/3 —— 主掉落门控 random(skill) > 10" do
    test "skill=0 时 random(0)=0，永不掉落" do
      assert Hunting.roll(%{a: "zhurou"}, 0, seq_rng([99])) == []
    end

    test "skill=10 时最大值 9 <= 10，永不掉落" do
      assert Hunting.roll(%{a: "zhurou"}, 10, seq_rng([9])) == []
    end

    test "skill=11 时最大值 10 <= 10，永不掉落" do
      assert Hunting.roll(%{a: "zhurou"}, 11, seq_rng([10])) == []
    end

    test "skill=12 时掷出 11 > 10 方可掉落主掉落（返回短引用）" do
      assert Hunting.roll(%{a: "zhurou"}, 12, seq_rng([11])) == ["zhurou"]
    end

    test "skill=12 时掷出 10 <= 10 不掉落" do
      assert Hunting.roll(%{a: "zhurou"}, 12, seq_rng([10])) == []
    end

    test "没有 drop_a 时始终返回 []" do
      assert Hunting.roll(%{b: "zhupi"}, 100, seq_rng([99])) == []
      assert Hunting.roll(%{}, 100, seq_rng([99])) == []
      assert Hunting.roll(nil, 100, seq_rng([99])) == []
    end
  end

  describe "roll/3 —— drop_c / drop_b 二选一（互斥）" do
    test "drop_c：random(skill)>60 且 random(5)>3 时掉落 c" do
      # 第1骰入门(>10)，第2骰 random(skill)(>60)，第3骰 random(5)(>3 即 4)
      assert Hunting.roll(%{a: "zhurou", c: "xiongdan"}, 61,
                          seq_rng([11, 61, 4])) == ["zhurou", "xiongdan"]
    end

    test "drop_c 稀有度门 random(5)>3 不通过则不掉 c" do
      # random(5)=3 不满足 >3，b 为 nil，只掉 a
      assert Hunting.roll(%{a: "zhurou", c: "xiongdan"}, 61,
                          seq_rng([11, 61, 3])) == ["zhurou"]
    end

    test "drop_c random(skill) 不大于 60 时不进入 c 分支" do
      assert Hunting.roll(%{a: "zhurou", c: "xiongdan"}, 61,
                          seq_rng([11, 50, 4])) == ["zhurou"]
    end

    test "drop_b：random(skill)>30 且 random(4)>2 时掉落 b" do
      # 第1骰入门，第2骰 random(skill)(>30)，第3骰 random(4)(>2 即 3)
      assert Hunting.roll(%{a: "zhurou", b: "zhupi"}, 31,
                          seq_rng([11, 31, 3])) == ["zhurou", "zhupi"]
    end

    test "drop_b 稀有度门 random(4)>2 不通过则不掉 b" do
      assert Hunting.roll(%{a: "zhurou", b: "zhupi"}, 31,
                          seq_rng([11, 31, 2])) == ["zhurou"]
    end

    test "drop_b random(skill) 不大于 30 时不进入 b 分支" do
      assert Hunting.roll(%{a: "zhurou", b: "zhupi"}, 31,
                          seq_rng([11, 20, 3])) == ["zhurou"]
    end

    test "drop_c 优先于 drop_b（互斥，c 命中则不再掷 b）" do
      # 三项齐全，c 分支命中 -> 结果含 c 不含 b
      assert Hunting.roll(%{a: "zhurou", b: "zhupi", c: "xiongdan"}, 61,
                          seq_rng([11, 61, 4])) == ["zhurou", "xiongdan"]
    end

    test "drop_c 不命中时退回 drop_b" do
      # c 的 random(5)=3 不通过，b 的 random(skill)=50>30 且 random(4)=3>2 通过
      assert Hunting.roll(%{a: "zhurou", b: "zhupi", c: "xiongdan"}, 61,
                          seq_rng([11, 61, 3, 50, 3])) == ["zhurou", "zhupi"]
    end
  end

  describe "drops_from_meta/1 —— 从 NPC meta 组装掉落配置" do
    test "有任一 drop_a/b/c 且为二进制时返回 drops map（atom 键）" do
      meta = %{drop_a: "zhurou", drop_b: "zhupi"}
      assert Hunting.drops_from_meta(meta) == %{a: "zhurou", b: "zhupi", c: nil}
    end

    test "仅 drop_c 时也能识别" do
      assert Hunting.drops_from_meta(%{drop_c: "xiongdan"}) ==
               %{a: nil, b: nil, c: "xiongdan"}
    end

    test "全 nil 或空 map 时返回 nil" do
      assert Hunting.drops_from_meta(%{drop_a: nil, drop_b: nil, drop_c: nil}) == nil
      assert Hunting.drops_from_meta(%{}) == nil
    end

    test "非 map 类型返回 nil" do
      assert Hunting.drops_from_meta("not a map") == nil
      assert Hunting.drops_from_meta(123) == nil
    end
  end

  describe "message/2 —— LPC tell_object 回执文案" do
    test "单件掉落生成对应文案" do
      resolved = [{:zhurou, item_def("野猪肉")}]

      assert Hunting.message("野猪", resolved) ==
               "你仔细翻寻野猪的尸体，从上面割下了一块野猪肉。\n\n"
    end

    test "多件掉落用「及」连接" do
      resolved = [
        {:zhurou, item_def("野猪肉")},
        {:zhupi, item_def("猪皮", "张")}
      ]

      assert Hunting.message("野猪", resolved) ==
               "你仔细翻寻野猪的尸体，从上面割下了一块野猪肉及一张猪皮。\n\n"
    end

    test "空列表返回 nil" do
      assert Hunting.message("野猪", []) == nil
    end
  end

  describe "resolve/1 —— 短物品引用解析为 {完整 key, 物品定义}" do
    test "短 id 解析到 clone_lib 定义" do
      [{key, item_defn}] = Hunting.resolve(["zhurou"])

      assert key == "clone_lib:zhurou"
      assert item_defn.name == "野猪肉"
    end

    test "查不到的条目静默丢弃" do
      assert Hunting.resolve(["no:such_item"]) == []
    end
  end
end
