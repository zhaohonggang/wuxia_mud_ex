defmodule Kantele.QuestTest do
  use ExUnit.Case, async: true

  alias Kantele.Quest

  defp spec(file \\ "q1", kill \\ ["怪a", "怪b"], item \\ ["刀"]) do
    %{file: file, kill: kill, item: item}
  end

  describe "set_todo (LPC setToDo)" do
    test "登记成功，killed 按 spec.kill 预填 0" do
      {:ok, s} = Quest.set_todo(Quest.new(), spec())
      assert Quest.get_size(s) == 1
      assert Quest.get_todo(s, "q1") == %{killed: %{"怪a" => 0, "怪b" => 0}, item: %{}}
    end

    test "无效任务被拒 (:invalid)" do
      assert Quest.set_todo(Quest.new(), nil) == {:error, :invalid}
      assert Quest.set_todo(Quest.new(), %{kill: ["x"]}) == {:error, :invalid}
    end

    test "任务数达上限被拒 (:full)" do
      specs = Enum.map(1..20, &%{file: "q#{&1}", kill: []})
      {:ok, s} = Enum.reduce(specs, {:ok, Quest.new()}, fn spec, {:ok, acc} -> Quest.set_todo(acc, spec) end)
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
end