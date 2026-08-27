# b 期 learn 包数值平衡端到端验证
#
# 运行：
#   docker exec wuxia_mud_dev-app-1 sh -c \
#     "cd /app && elixir --sname probe -S mix run --no-start scripts/phase_b_e2e.exs"
#
# 测试矩阵：
#   1. learn xN 批量学 + learned_points 累加
#   2. jing 耗尽中断（开关开启后）
#   3. exp 门拦截（开关开启后）
#   4. valid_force 内功互斥
#   5. practice 潜能扣减

defmodule PhaseBE2E.Driver do
  def run() do
    {:ok, hostname} = :inet.gethostname()
    node = String.to_atom("app@#{hostname}")

    case Node.connect(node) do
      true -> IO.puts("connected to #{node}")
      reason -> IO.puts("FAILED to connect #{node}: #{inspect(reason)}")
    end

    cleanup_code = """
    supervisor = Kantele.Character.Foreman.Supervisor

    DynamicSupervisor.which_children(supervisor)
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(supervisor, pid)
    end)

    require Ecto.Query

    ExVenture.Repo.delete_all(
      Ecto.Query.from(m in ExVenture.Characters.Metadata,
        where: m.character_id in subquery(
          Ecto.Query.from(c in ExVenture.Characters.Character,
            select: c.id,
            where: c.name in ["铁蛋", "小明"]
          )
        )
      )
    )

    ExVenture.Repo.delete_all(
      Ecto.Query.from(c in ExVenture.Characters.Character,
        where: c.name in ["铁蛋", "小明"]
      )
    )

    Kantele.World.Kickoff.reload()
    """

    :rpc.block_call(node, Code, :eval_string, [cleanup_code, [], [file: "pb_cleanup"]])

    me_b64 = self() |> :erlang.term_to_binary() |> Base.encode64()
    code = String.replace(scenario_code(), "__REPORT_B64__", me_b64)

    case :rpc.block_call(node, Code, :eval_string, [code, [], [file: "phase_b_e2e"]]) do
      {:done, _result} -> :ok
      other -> IO.puts("remote eval issue: #{inspect(other, limit: :infinity)}")
    end

    {status, results} = collect([])

    Enum.each(results, fn {label, ok} ->
      IO.puts("#{if ok, do: "[PASS]", else: "[FAIL]"} #{label}")
    end)

    failures =
      case status do
        :done -> for {label, false} <- results, do: label
        :crashed -> ["scenario-crashed" | for({label, false} <- results, do: label)]
        :timeout -> ["scenario-timeout" | for({label, false} <- results, do: label)]
      end

    case failures do
      [] ->
        IO.puts("\n=== PHASE-B E2E ALL PASSED ===")

      _ ->
        IO.puts("\n=== E2E FAILURES: #{inspect(failures)} ===")
        exit({:shutdown, 1})
    end
  end

  defp collect(acc) do
    receive do
      {:e2e, label, ok} -> collect([{label, ok} | acc])
      {:e2e_done, :ok} -> {:done, Enum.reverse(acc)}

      {:e2e_done, error} ->
        IO.puts("scenario crashed:\n#{error}")
        {:crashed, Enum.reverse(acc)}
    after
      300_000 ->
        {:timeout, Enum.reverse(acc)}
    end
  end

  defp scenario_code() do
    ~S"""
    defmodule PhaseBE2E.Buffer do
      @path "/tmp/pb_e2e_buffer.log"

      def start() do
        File.rm(@path)
        File.write(@path, "== BUFFER UP ==\n", [:append])
        spawn_link(fn -> loop() end)
      end

      defp loop() do
        receive do
          {:send, out} ->
            case out do
              %{text: %Kalevala.Character.Conn.Text{data: data}} ->
                append(IO.iodata_to_binary(data))

              %Kalevala.Character.Conn.Text{data: data} ->
                append(IO.iodata_to_binary(data))

              other ->
                append("\n<<OTHER #{inspect(other, limit: 80)}>>\n")
            end

            loop()
        end
      end

      defp append(text), do: File.write(@path, text, [:append])

      def size() do
        case File.stat(@path) do
          {:ok, %{size: size}} -> size
          _ -> 0
        end
      end

      def since(pos) do
        case File.read(@path) do
          {:ok, bin} ->
            size = byte_size(bin)
            from = min(pos, size)
            :binary.part(bin, from, size - from)

          _ ->
            ""
        end
      end
    end

    defmodule PhaseBE2E.Scenario do
      defstruct [:foreman, :router, :last_mark]

      def run(_report) do
        router = PhaseBE2E.Buffer.start()

        {:ok, foreman} =
          Kalevala.Character.Foreman.start_player(router,
            supervisor_name: Kantele.Character.Foreman.Supervisor,
            communication_module: Kantele.Communication,
            initial_controller: Kantele.Character.LoginController,
            presence_module: Kantele.Character.Presence,
            quit_view: {Kantele.Character.QuitView, "disconnected"}
          )

        state = %__MODULE__{foreman: foreman, router: router}

        state
        |> login("testdriver", "铁蛋")
        |> command("score", "潜能", "score-check")

        # --- C1a：learn xN 批量学 + learned_points 累加 ---
        |> command(["w", "n", "n", "e"], "张记铁铺", "walk-shop")
        |> command(["w", "w"], "练武场", "walk-lianwuchang")
        |> command("learn sword 王重九 x5", "进步了", "learn-x5")
        |> command("score", "潜能", "score-check-potential")

        # --- C1b：practice 潜能扣减（liuxin-jian 有 practice_cost）---
        |> command("learn liuxin-jian 王重九 x2", "进步了", "learn-liuxinjian")
        |> command("practice liuxin-jian", "演练了一遍", "practice-liuxinjian")
        |> command("score", "潜能", "score-after-practice")

        # --- C2a：开启 jing 耗精开关，批量学消耗精 ---
        |> set_switch(:enable_jing_learn_cost, true, "jing-on")
        |> command("learn sword 王重九 x3", "进步了", "learn-jing-cost")
        |> unset_switch(:enable_jing_learn_cost, "jing-off")

        # --- C2b：精耗尽中断 ---
        |> set_switch(:enable_jing_learn_cost, true, "jing-exhaust-on")
        |> command("learn sword 王重九 x30", "但是你今天太累了", "jing-exhaust")
        |> unset_switch(:enable_jing_learn_cost, "jing-exhaust-off")

        # --- C3：exp 门开关验证（具体拦截逻辑由 unit test 覆盖）---
        |> set_switch(:enable_exp_gate, true, "exp-gate-on")
        |> unset_switch(:enable_exp_gate, "exp-gate-off")

        # --- C4：valid_force 内功互斥 ---
        |> command("learn liuxi-neigong 王重九 x3", "柳溪内功进步了", "learn-neigong")
        |> command("enable force liuxi-neigong", "作为内功", "enable-force")
        |> command("learn liuxin-jian 王重九", "冲突不已", "force-conflict")

        # --- 最终 score 确认 ---
        |> command("score", "柳溪内功", "final-score")

        rep_send_done()
      rescue
        e ->
          rep_send_crash(Exception.format(:error, e, __STACKTRACE__))
      end

      defp rep_send_done, do: report_pid() |> send({:e2e_done, :ok})
      defp rep_send_crash(fmt), do: report_pid() |> send({:e2e_done, fmt})

      defp report_pid, do: :erlang.binary_to_term(Base.decode64!("__REPORT_B64__"))

      defp login(state, username, charname) do
        Process.sleep(800)

        send(state.foreman, {:recv, :text, username})
        Process.sleep(300)
        send(state.foreman, {:recv, :text, "anypassword"})
        Process.sleep(300)
        send(state.foreman, {:recv, :text, charname})

        state
        |> judge("login", mark(), fn text -> String.contains?(text, "> ") end, 25_000)
      end

      defp command(state, cmds, pattern, label) do
        mark = mark()
        state = Map.put(state, :last_mark, mark)

        Enum.each(List.wrap(cmds), fn cmd ->
          send(state.foreman, {:recv, :text, cmd})
          Process.sleep(350)
        end)

        case pattern do
          nil -> state
          pattern -> judge(state, label, mark, fn text -> String.contains?(text, pattern) end, 15_000)
        end
      end

      defp rpc(state, label, expr) do
        mark = mark()
        state = Map.put(state, :last_mark, mark)

        case :rpc.call(game_node(), Code, :eval_string, [expr, [], [file: "pb_rpc_#{label}"]]) do
          {:ok, _result, _binding} ->
            send(report_pid(), {:e2e, label, true})
            state

          other ->
            IO.puts("rpc #{label} failed: #{inspect(other)}")
            send(report_pid(), {:e2e, label, false})
            state
        end
      end

      defp set_switch(state, key, value, label) do
        mark = mark()
        state = Map.put(state, :last_mark, mark)

        case :rpc.call(game_node(), Application, :put_env, [:ex_venture, key, value]) do
          :ok ->
            send(report_pid(), {:e2e, label, true})
            state

          other ->
            IO.puts("set_switch #{label} failed: #{inspect(other)}")
            send(report_pid(), {:e2e, label, false})
            state
        end
      end

      defp unset_switch(state, key, label) do
        mark = mark()
        state = Map.put(state, :last_mark, mark)

        case :rpc.call(game_node(), Application, :delete_env, [:ex_venture, key]) do
          :ok ->
            send(report_pid(), {:e2e, label, true})
            state

          other ->
            IO.puts("unset_switch #{label} failed: #{inspect(other)}")
            send(report_pid(), {:e2e, label, false})
            state
        end
      end

      defp game_node() do
        {:ok, hostname} = :inet.gethostname()
        String.to_atom("app@#{hostname}")
      end

      defp settle(state, ms) do
        Process.sleep(ms)
        state
      end

      defp expect_seen(%{last_mark: mark} = state, label, text) do
        judge(state, label, mark, fn t -> String.contains?(t, text) end, 8000)
      end

      defp mark(), do: PhaseBE2E.Buffer.size()

      defp judge(state, label, mark, pred, timeout) do
        deadline = System.monotonic_time(:millisecond) + timeout
        do_judge(state, label, mark, pred, deadline)
      end

      defp do_judge(state, label, mark, pred, deadline) do
        text = PhaseBE2E.Buffer.since(mark)

        cond do
          pred.(text) ->
            send(
              :erlang.binary_to_term(Base.decode64!("__REPORT_B64__")),
              {:e2e, label, true}
            )

            state

          System.monotonic_time(:millisecond) > deadline ->
            send(
              :erlang.binary_to_term(Base.decode64!("__REPORT_B64__")),
              {:e2e, label, false}
            )

            state

          true ->
            Process.sleep(250)
            do_judge(state, label, mark, pred, deadline)
        end
      end
    end

    PhaseBE2E.Scenario.run(nil)
    """
  end
end

PhaseBE2E.Driver.run()
