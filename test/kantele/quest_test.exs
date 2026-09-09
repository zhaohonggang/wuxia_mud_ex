defmodule Kantele.QuestTest do
  use ExUnit.Case, async: true

  alias Kantele.Quest

  defp spec(file \\ "q1", kill \\ ["怪a", "怪b"], item \\ ["刀"]) do
    %{file: file, kill: kill, item: item}
  end

  describe "set_todo (LPC setToDo)" do
    test "登记成功，killed 按 spec.kill 预填 0（v2 带 meta/accepted_at/limit）" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec(), now: 1000)
      assert Quest.get_size(s) == 1
      assert Quest.get_todo(s, "q1") == %{killed: %{"怪a" => 0, "怪b" => 0}, item: %{}, meta: %{}, accepted_at: 1000, limit: 0}
    end

    test "无效任务被拒 (:invalid)" do
      assert Quest.set_todo(Quest.new(), nil) == {:error, :invalid}
      assert Quest.set_todo(Quest.new(), %{kill: ["x"]}) == {:error, :invalid}
    end

    test "任务数达上限被拒 (:full)" do
      specs = Enum.map(1..20, &%{file: "q#{&1}", kill: []})

      {:ok, s} =
        Enum.reduce(specs, {:ok, Quest.new()}, fn spec, {:ok, acc} ->
          Quest.set_todo(acc, spec)
        end)

      assert Quest.get_size(s) == 20
      assert Quest.set_todo(s, spec("q21")) == {:error, :full}
    end

    test "重复登记被拒 (:duplicate)" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      assert Quest.set_todo(s, spec()) == {:error, :duplicate}
    end
  end

  describe "add_killed / get_killed (LPC addKilled/getKilled)" do
    test "声明过的怪可累计" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      {:ok, s} = Quest.add_killed(s, spec(), "怪a", 1)
      {:ok, s} = Quest.add_killed(s, spec(), "怪a", 2)
      assert Quest.get_killed(s, spec(), "怪a") == 3
      assert Quest.get_killed(s, spec(), "怪b") == 0
    end

    test "未声明的怪被拒 (:unknown)" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      assert Quest.add_killed(s, spec(), "野狼", 1) == {:error, :unknown}
    end

    test "无该任务被拒 (:no_todo)" do
      s = Quest.new()
      assert Quest.add_killed(s, spec(), "怪a", 1) == {:error, :no_todo}
    end

    test "无效 spec 击杀返回 0" do
      s = Quest.new()
      assert Quest.get_killed(s, nil, "怪a") == 0
    end
  end

  describe "add_item / get_item (LPC addItem/getItem)" do
    test "声明过的物可累计" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      {:ok, s} = Quest.add_item(s, spec(), "刀", 2)
      assert Quest.get_item(s, spec(), "刀") == 2
      assert Quest.get_item(s, spec(), "剑") == 0
    end

    test "未声明的物被拒 (:unknown)" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      assert Quest.add_item(s, spec(), "剑", 1) == {:error, :unknown}
    end

    test "无该任务被拒 (:no_todo)" do
      assert Quest.add_item(Quest.new(), spec(), "刀", 1) == {:error, :no_todo}
    end
  end

  describe "solved (LPC setSolved/isSolved/delSolved)" do
    test "标记/查询/移除已解" do
      s = Quest.new()
      assert Quest.is_solved(s, spec()) == false

      {:ok, s} = Quest.set_solved(s, spec())
      assert Quest.is_solved(s, spec()) == true
      assert Quest.get_solved(s) == ["q1"]

      # 已解不重复添加
      {:ok, s2} = Quest.set_solved(s, spec())
      assert Quest.get_solved(s2) == ["q1"]

      s = Quest.del_solved(s, "q1")
      assert Quest.is_solved(s, spec()) == false
      assert Quest.get_solved(s) == []
    end

    test "无效 spec 不解" do
      assert Quest.set_solved(Quest.new(), nil) == {:error, :invalid}
    end
  end

  describe "del_todo (LPC delToDo)" do
    test "移除在办任务" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      assert Quest.get_size(s) == 1
      s = Quest.del_todo(s, "q1")
      assert Quest.get_size(s) == 0
      assert Quest.get_todo(s, "q1") == nil
    end
  end

  describe "register_kill (LPC doKilled 本地聚合)" do
    test "命中在办任务的击杀键则累计" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec("q1", ["怪a"], []))
      {:ok, s} = Quest.register_kill(s, "怪a")
      {:ok, s} = Quest.register_kill(s, "怪a")
      assert Quest.get_killed(s, spec("q1", ["怪a"], []), "怪a") == 2
    end

    test "未声明的击杀键不改变任何任务" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec("q1", ["怪a"], []))
      assert {:ok, s2} = Quest.register_kill(s, "野狼")
      assert Quest.get_killed(s2, spec("q1", ["怪a"], []), "怪a") == 0
    end

    test "多个在办任务共享击杀键都累计" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec("q1", ["怪a"], []))
      {:ok, s} = Quest.set_todo(s, spec("q2", ["怪a", "怪b"], []))
      {:ok, s} = Quest.register_kill(s, "怪a")
      assert Quest.get_killed(s, spec("q1", ["怪a"], []), "怪a") == 1
      assert Quest.get_killed(s, spec("q2", ["怪a", "怪b"], []), "怪a") == 1
      assert Quest.get_killed(s, spec("q2", ["怪a", "怪b"], []), "怪b") == 0
    end

    test "空状态原样返回" do
      assert {:ok, s} = Quest.register_kill(Quest.new(), "怪a")
      assert Quest.get_todo_list(s) == %{}
    end
  end

  describe "宿主派发 (QUEST_D 级)" do
    test "ask_quest 无任务配置返回友好文案" do
      assert Quest.ask_quest(%{}, %{}) == {:error, "老朽手头暂无任务可托付。"}
    end

    test "ask_quest 有任务配置返回规格" do
      npc = %{meta: %{quest: %{file: "song-yupai", kill: ["yezhu"]}}}
      assert Quest.ask_quest(npc, %{}) == {:ok, %{file: "song-yupai", kill: ["yezhu"]}}
    end

    test "cancel_quest 无任务配置返回友好文案" do
      assert Quest.cancel_quest(%{}, %{}) == {:error, "老朽手头暂无你的任务可作罢。"}
    end

    test "cancel_quest 有任务配置返回 quest file" do
      npc = %{meta: %{quest: %{file: "song-yupai"}}}
      assert Quest.cancel_quest(npc, %{}) == {:ok, "song-yupai"}
    end
  end

  describe "set_todo v2 前置条件（chain/mutex/repeatable/meta）" do
    test "meta 收割 type/level/master/place" do
      spec = %{file: "shimen", kill: ["dadao"], type: "kill", level: 5, master_name: "杨掌门", master_id: "yang", place: "少林"}
      {:ok, s} = Quest.set_todo(Quest.new(), spec, now: 100)
      task = Quest.get_todo(s, "shimen")
      assert task.meta == %{type: "kill", level: 5, master_name: "杨掌门", master_id: "yang", place: "少林"}
      assert task.accepted_at == 100
      assert task.limit == 0
    end

    test "limit 可来自 spec 或被 opts 覆盖" do
      {:ok, s} = Quest.set_todo(Quest.new(), %{file: "q", kill: [], limit: 600})
      assert Quest.get_todo(s, "q").limit == 600
      {:ok, s2} = Quest.set_todo(Quest.new(), %{file: "q", kill: []}, limit: 120)
      assert Quest.get_todo(s2, "q").limit == 120
    end

    test "chain 前置未全解被拒 (:chain_blocked)，全解后可接" do
      spec = %{file: "step3", kill: [], chain: ["step1", "step2"]}
      assert Quest.set_todo(Quest.new(), spec) == {:error, :chain_blocked}
      {:ok, s} = Quest.set_solved(Quest.new(), %{file: "step1"})
      {:ok, s} = Quest.set_solved(s, %{file: "step2"})
      assert {:ok, s} = Quest.set_todo(s, spec)
      assert Quest.chain_open?(s, spec)
    end

    test "mutex 互斥在办中防接 (:mutex_blocked)，移除后可接" do
      {:ok, s} = Quest.set_todo(Quest.new(), %{file: "trade_b", kill: []})
      assert Quest.set_todo(s, %{file: "trade_a", kill: [], mutex: ["trade_b"]}) == {:error, :mutex_blocked}
      s = Quest.del_todo(s, "trade_b")
      assert {:ok, _s} = Quest.set_todo(s, %{file: "trade_a", kill: [], mutex: ["trade_b"]})
    end

    test "已解且不可重复被拒 (:done)；默认可重复可再接" do
      spec = %{file: "once", kill: []}
      {:ok, s} = Quest.set_todo(Quest.new(), spec)
      {:ok, s} = Quest.set_solved(s, spec)
      s = Quest.del_todo(s, "once")
      assert {:ok, _s} = Quest.set_todo(s, spec)

      spec_once = %{file: "once2", kill: [], repeatable: false}
      {:ok, s2} = Quest.set_todo(Quest.new(), spec_once)
      {:ok, s2} = Quest.set_solved(s2, spec_once)
      s2 = Quest.del_todo(s2, "once2")
      assert Quest.set_todo(s2, spec_once) == {:error, :done}
    end
  end

  describe "quest_count / milestone" do
    test "bump 累加、reset 清零、默认 0" do
      assert Quest.quest_count(Quest.new()) == 0
      s = Quest.bump_quest_count(Quest.new())
      assert Quest.quest_count(s) == 1
      s = Quest.bump_quest_count(s, 2)
      assert Quest.quest_count(s) == 3
      assert Quest.quest_count(Quest.reset_quest_count(s)) == 0
    end

    test "milestone 命中阶梯返回 tier，其余 :none" do
      assert Quest.milestone(29) == :none
      assert Quest.milestone(30) == {:ok, 30}
      assert Quest.milestone(50) == {:ok, 50}
      assert Quest.milestone(1000) == {:ok, 1000}
      assert Quest.milestone(0) == :none
      assert Quest.milestone(nil) == :none
    end

    test "milestone_ladder 返回去重升序阶梯" do
      ladder = Quest.milestone_ladder()
      assert 30 in ladder
      assert 1000 in ladder
      assert ladder == Enum.uniq(ladder)
    end
  end

  describe "check_timeout" do
    test "limit 超时任务被列出，无时限不过期" do
      {:ok, s} = Quest.set_todo(Quest.new(), %{file: "slow", kill: []}, now: 100, limit: 50)
      {:ok, s} = Quest.set_todo(s, %{file: "free", kill: []}, now: 100)
      assert Quest.check_timeout(s, 149) == []
      assert [{"slow", _}] = Quest.check_timeout(s, 150)
      assert Enum.map(Quest.check_timeout(s, 500), &elem(&1, 0)) == ["slow"]
    end
  end

  describe "cancel_with_penalty" do
    test "无该任务返回 :no_todo" do
      assert Quest.cancel_with_penalty(Quest.new(), "x") == {:error, :no_todo}
    end

    test "kill 扣威望/贡献/阅历，level 10 系数 1" do
      {:ok, s} = Quest.set_todo(Quest.new(), %{file: "shimen", kill: [], type: "kill", level: 10})
      assert {:ok, s, %{weiwang: w, gongxian: g, score: sc}} = Quest.cancel_with_penalty(s, "shimen")
      assert {w, g, sc} == {10, 5, 50}
      assert Quest.get_size(s) == 0
    end

    test "level 20 惩罚翻倍（系数 2）" do
      {:ok, s} = Quest.set_todo(Quest.new(), %{file: "shimen", kill: [], type: "kill", level: 20})
      assert {:ok, _s, %{weiwang: w}} = Quest.cancel_with_penalty(s, "shimen")
      assert w == 20
    end

    test "letter 仅扣阅历" do
      {:ok, s} = Quest.set_todo(Quest.new(), %{file: "letter", kill: [], type: "letter"})
      assert {:ok, _s, %{score: sc}} = Quest.cancel_with_penalty(s, "letter")
      assert sc == 20
    end
  end

  describe "accept_check（计数门槛）" do
    setup do
      spec = %{file: "q", kill: ["怪a"], item: ["刀"]}
      {:ok, s} = Quest.set_todo(Quest.new(), spec)
      {:ok, %{spec: spec, s: s}}
    end

    test "击杀门槛：未杀 :kill_insufficient，杀后 :ok", %{spec: spec, s: state} do
      assert Quest.accept_check(state, spec, %{kind: :kill}) == {:error, :kill_insufficient}
      {:ok, s2} = Quest.register_kill(state, "怪a")
      assert Quest.accept_check(s2, spec, %{kind: :kill}) == :ok
    end

    test "物品门槛：数量不足 :item_insufficient，足够 :ok", %{spec: spec, s: state} do
      assert Quest.accept_check(state, spec, %{kind: :item, item: "刀", count: 2}) == {:error, :item_insufficient}
      {:ok, s2} = Quest.add_item(state, spec, "刀", 2)
      assert Quest.accept_check(s2, spec, %{kind: :item, item: "刀", count: 2}) == :ok
    end

    test "非法证据 :bad_evidence", %{spec: spec, s: state} do
      assert Quest.accept_check(state, spec, %{kind: :foo}) == {:error, :bad_evidence}
    end
  end

  describe "serialize / deserialize v2" do
    test "roundtrip 保留 quest_count 与任务 meta" do
      spec = %{file: "shimen", kill: ["dadao"], type: "kill", level: 5}
      {:ok, s} = Quest.set_todo(Quest.new(), spec, now: 200, limit: 60)
      s = Quest.bump_quest_count(s, 30)
      restored = Quest.deserialize(Quest.serialize(s))
      assert restored == s
      assert Quest.quest_count(restored) == 30
      assert Quest.get_todo(restored, "shimen").meta.type == "kill"
    end

    test "旧落盘数据（无 quest_count/无任务 meta）兼容" do
      old = %{todo: %{"q1" => %{killed: %{"怪a" => 2}, item: %{}}}, solved: ["q1"]}
      restored = Quest.deserialize(old)
      assert Quest.quest_count(restored) == 0
      task = Quest.get_todo(restored, "q1")
      assert task.killed == %{"怪a" => 2}
      assert task.meta == %{}
      assert task.limit == 0
    end

    test "非法输入回退空状态" do
      assert Quest.deserialize(nil) == Quest.new()
      assert Quest.deserialize(%{todo: []}) == Quest.new()
    end
  end
end
