defmodule Kantele.Character.SchemeTest do
  @moduledoc """
  `Kantele.Character.Scheme` 纯逻辑测试：解析、REPEAT/LOOP/BREAK 控制流、
  `cmd:case` 失败动作、以及 `scheme start` 门控。

  不依赖 DB / 进程 / 命令执行；运行态用注入的 recording runner 模拟。
  """
  use ExUnit.Case, async: true

  alias Kantele.Character.Scheme
  alias Kantele.Character.Stats

  setup do
    Process.put(:scheme_calls, [])
    :ok
  end

  # ---------------------------------------------------------------------------
  # 解析 / 初始化
  # ---------------------------------------------------------------------------

  test "parse_steps 按行拆分、trim 并滤空行" do
    steps = Scheme.parse_steps("lianxi force\n\n  study  \n\n")
    assert steps == ["lianxi force", "study"]
  end

  test "init_state 从步骤列表生成初始态" do
    state = Scheme.init_state(["a", "b"])
    assert state.steps == ["a", "b"]
    assert state.step == 0
    assert state.repeat_stack == []
    assert state.last_fail == 0
  end

  # ---------------------------------------------------------------------------
  # current_step / advance
  # ---------------------------------------------------------------------------

  test "current_step 解析 cmd:case，缺省 IGNORE" do
    state = Scheme.init_state(["lianxi:RETRY", "study", "REPEAT"])
    assert Scheme.current_step(state) == {0, "lianxi", "RETRY"}
    assert Scheme.current_step(%{state | step: 1}) == {1, "study", "IGNORE"}
    assert Scheme.current_step(%{state | step: 2}) == {2, "REPEAT", "IGNORE"}
  end

  test "current_step 越界返回 :done" do
    state = Scheme.init_state(["a"])
    assert Scheme.current_step(%{state | step: 1}) == :done
    assert Scheme.current_step(%{state | step: -1}) == :done
  end

  test "advance 成功推进，越界 :done" do
    state = Scheme.init_state(["a", "b"])
    assert Scheme.advance(state) == {:ok, %{state | step: 1}}
    assert Scheme.advance(%{state | step: 1}) == {:done}
  end

  # ---------------------------------------------------------------------------
  # 控制流：REPEAT / LOOP / BREAK
  # ---------------------------------------------------------------------------

  test "apply_repeat 配对 LOOP 并压栈，指向循环体首行" do
    state = Scheme.init_state(["REPEAT", "lianxi", "LOOP"])
    assert {:ok, ns, "开始循环。\n"} = Scheme.apply_repeat(state)
    assert ns.step == 1
    assert ns.repeat_stack == [{0, 2}]
  end

  test "apply_repeat 缺 LOOP 取消" do
    state = Scheme.init_state(["REPEAT", "lianxi"])
    assert {:cancel, _} = Scheme.apply_repeat(state)
  end

  test "apply_repeat 嵌套计数正确配对外层 LOOP" do
    # REPEAT(0) a REPEAT(2) b LOOP(4) LOOP(5)：扫描从 1 起，内 REPEAT 使 count=2，
    # 第一个 LOOP(4) count-1=1 不配对，第二个 LOOP(5) count-1=0 配对
    state = Scheme.init_state(["REPEAT", "a", "REPEAT", "b", "LOOP", "LOOP"])
    assert {:ok, ns, _} = Scheme.apply_repeat(state)
    assert ns.repeat_stack == [{0, 5}]
  end

  test "apply_loop 跳回循环体首行" do
    state = %{Scheme.init_state(["REPEAT", "lianxi", "LOOP"]) | repeat_stack: [{0, 2}]}
    assert {:ok, ns, "Loop.\n"} = Scheme.apply_loop(state)
    assert ns.step == 1
  end

  test "apply_loop 无栈取消" do
    state = Scheme.init_state(["LOOP"])
    assert {:cancel, _} = Scheme.apply_loop(state)
  end

  test "apply_break 跳出循环指向 LOOP 之后并弹栈" do
    state = %{Scheme.init_state(["REPEAT", "lianxi", "BREAK", "LOOP", "study"])
             | repeat_stack: [{0, 3}]}
    assert {:ok, ns, "Ok.\n"} = Scheme.apply_break(state)
    assert ns.step == 4
    assert ns.repeat_stack == []
  end

  test "apply_break 无栈取消" do
    state = Scheme.init_state(["BREAK"])
    assert {:cancel, _} = Scheme.apply_break(state)
  end

  # ---------------------------------------------------------------------------
  # failure_action
  # ---------------------------------------------------------------------------

  test "failure_action 决策" do
    state = Scheme.init_state(["REPEAT", "lianxi", "LOOP"])
    assert Scheme.failure_action(state, "RETRY") == {:retry}
    assert Scheme.failure_action(state, "IGNORE") == {:advance}
    assert Scheme.failure_action(state, "study") == {:fallback, "study"}

    stacked = %{state | repeat_stack: [{0, 2}]}
    assert Scheme.failure_action(stacked, "CONTINUE") == {:loop}
    assert Scheme.failure_action(stacked, "BREAK") == {:break}

    empty = Scheme.init_state(["lianxi"])
    assert {:cancel, _} = Scheme.failure_action(empty, "CONTINUE")
    assert {:cancel, _} = Scheme.failure_action(empty, "BREAK")
  end

  # ---------------------------------------------------------------------------
  # start_gate（照 LPC main() 顺序：schedule / room / exp / potential / players）
  # ---------------------------------------------------------------------------

  defp stats(combat_exp, potential, learned) do
    %Stats{combat_exp: combat_exp, potential: potential, learned_points: learned}
  end

  test "start_gate 全部满足返回 :ok" do
    flags = ["sleep_room", "no_fight"]
    assert Scheme.start_gate("plan", flags, stats(100_000, 500, 0), 3) == :ok
  end

  test "start_gate 无计划被拒" do
    assert {:error, "你目前还没有制订计划。\n"} =
             Scheme.start_gate(nil, ["sleep_room"], stats(100_000, 500, 0), 0)

    assert {:error, "你目前还没有制订计划。\n"} =
             Scheme.start_gate("", ["sleep_room"], stats(100_000, 500, 0), 0)
  end

  test "start_gate 聊天室被拒" do
    flags = ["chat_room", "sleep_room", "no_fight"]
    assert {:error, "你不能在聊天室里面执行计划。\n"} = Scheme.start_gate("p", flags, stats(100_000, 500, 0), 0)
  end

  test "start_gate 非休息室被拒" do
    assert {:error, "你必须在能够休息的地方才能执行计划。\n"} =
             Scheme.start_gate("p", ["no_fight"], stats(100_000, 500, 0), 0)
  end

  test "start_gate 非安全室被拒" do
    assert {:error, "你必须在安全的地方才能执行计划。\n"} =
             Scheme.start_gate("p", ["sleep_room"], stats(100_000, 500, 0), 0)
  end

  test "start_gate 实战经验不足被拒" do
    assert {:error, "你的实战经验太浅薄，还是先好好锻炼锻炼再说吧。\n"} =
             Scheme.start_gate("p", ["sleep_room", "no_fight"], stats(10_000, 500, 0), 0)
  end

  test "start_gate 可用潜能不足被拒（potential - learned_points < 100）" do
    assert {:error, "你的潜能太少，难以开展计划。\n"} =
             Scheme.start_gate("p", ["sleep_room", "no_fight"], stats(100_000, 50, 0), 0)
  end

  test "start_gate 房间人数过多被拒" do
    assert {:error, "这里的人实在太多了，你难以静心开展计划。\n"} =
             Scheme.start_gate("p", ["sleep_room", "no_fight"], stats(100_000, 500, 0), 13)
  end

  # ---------------------------------------------------------------------------
  # 全流程模拟（driving advance_step + recording runner）
  # ---------------------------------------------------------------------------

  # runner：记录「被调用」的命令到 Process.get(:scheme_calls)；按 behaviors 决定
  # 本次调用返回 :ok / :error。记录成功执行的命令用于断言推进顺序。
  defp run_recorder(behaviors) do
    fn cmd ->
      calls = Process.get(:scheme_calls, [])
      Process.put(:scheme_calls, [cmd | calls])

      case Map.get(behaviors, cmd, :ok) do
        :ok -> {:ok, cmd}
        :error -> {:error, cmd}
      end
    end
  end

  defp simulate(text, behaviors, cap \\ 200) do
    runner = run_recorder(behaviors)
    state = Scheme.parse_steps(text) |> Scheme.init_state()
    simulate(state, runner, [], cap)
  end

  defp simulate(_state, _runner, acc, 0), do: Enum.reverse(acc)

  defp simulate(state, runner, acc, cap) do
    case Scheme.advance_step(state, runner) do
      {:done} ->
        Enum.reverse(acc)

      {:done_cmd, cmd, _extra} ->
        Enum.reverse([cmd | acc])

      {:ok, new_state, cmd, _extra} ->
        simulate(new_state, runner, [cmd | acc], cap - 1)

      {:control, new_state} ->
        simulate(new_state, runner, acc, cap - 1)

      {:retry, new_state} ->
        simulate(new_state, runner, acc, cap - 1)

      {:ignored, new_state} ->
        simulate(new_state, runner, acc, cap - 1)

      {:done_ignored} ->
        Enum.reverse(acc)

      {:cancel, _reason} ->
        {:cancel, Enum.reverse(acc)}
    end
  end

  defp calls, do: Process.get(:scheme_calls, []) |> Enum.reverse()

  test "线性计划依次执行并结束" do
    assert simulate("lianxi\nstudy\nduanli", %{}) == ["lianxi", "study", "duanli"]
  end

  test "REPEAT/LOOP 反复执行循环体" do
    # 每轮执行一次 lianxi；cap=6 应约 3 次
    assert simulate("REPEAT\nlianxi\nLOOP", %{}, 6) == ["lianxi", "lianxi", "lianxi"]
  end

  test "BREAK（控制流）跳出循环并续跑到结束" do
    # REPEAT(0) lianxi(1) BREAK(2) LOOP(3) study(4)：lianxi 一次后 BREAK 跳到 study
    assert simulate("REPEAT\nlianxi\nBREAK\nLOOP\nstudy", %{}, 20) == ["lianxi", "study"]
  end

  test "RETRY：命令失败则反复重试同一步（不推进）" do
    simulate("lianxi:RETRY\nstudy", %{"lianxi" => :error}, 5)
    assert calls() == ["lianxi", "lianxi", "lianxi", "lianxi", "lianxi"]
  end

  test "CONTINUE：命令失败则回到循环体首行（不跳出）" do
    simulate("REPEAT\nlianxi:CONTINUE\nLOOP", %{"lianxi" => :error}, 7)
    assert calls() == ["lianxi", "lianxi", "lianxi", "lianxi", "lianxi", "lianxi"]
  end

  test "BREAK 失败动作：跳出循环后结束（后续不执行）" do
    # REPEAT(0) lianxi:BREAK(1) LOOP(2) study(3)：lianxi 失败后 BREAK 跳到 study，结束
    assert simulate("REPEAT\nlianxi:BREAK\nLOOP\nstudy", %{"lianxi" => :error}, 20) == ["study"]
  end

  test "IGNORE：命令失败被忽略并继续" do
    # lianxi 失败被忽略 → study 照常执行
    assert simulate("lianxi:IGNORE\nstudy", %{"lianxi" => :error}, 20) == ["study"]
  end

  test "默认 case：失败则执行回退命令后继续" do
    # lianxi 失败 → 执行 fallback_cmd 后推进到 done
    assert simulate("lianxi:fallback_cmd", %{"lianxi" => :error, "fallback_cmd" => :ok}, 20) ==
             ["fallback_cmd"]
  end

  test "嵌套 REPEAT/LOOP 使用配对栈（内层循环 study）" do
    text = "REPEAT\nlianxi\nREPEAT\nstudy\nLOOP\nLOOP"
    result = simulate(text, %{}, 8)
    assert "lianxi" in result
    assert Enum.count(result, &(&1 == "study")) >= 2
  end
end
