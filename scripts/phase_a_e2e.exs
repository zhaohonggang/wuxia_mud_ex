# a 期新系统端到端冒烟（商店/进食/问询/拜师/门派/打坐/中文别名/房间flags）
#
# 运行：
#   docker exec wuxia_mud_dev-app-1 sh -c \
#     "cd /app && elixir --sname probe -S mix run --no-start scripts/phase_a_e2e.exs"
#
# 与 combat_e2e.exs 同一套机制：连接游戏节点 → 独立 Router 进程收输出落盘
# → 标记后动作、匹配文件增量断言。

defmodule PhaseAE2E.Driver do
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
            where: c.name in ["铁蛋", "阿福"]
          )
        )
      )
    )

    ExVenture.Repo.delete_all(
      Ecto.Query.from(c in ExVenture.Characters.Character,
        where: c.name in ["铁蛋", "阿福"]
      )
    )

    Kantele.World.Kickoff.reload()
    """

    :rpc.block_call(node, Code, :eval_string, [cleanup_code, [], [file: "pa_cleanup"]])

    me_b64 = self() |> :erlang.term_to_binary() |> Base.encode64()
    code = String.replace(scenario_code(), "__REPORT_B64__", me_b64)

    case :rpc.block_call(node, Code, :eval_string, [code, [], [file: "phase_a_e2e"]]) do
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
        IO.puts("\n=== PHASE-A E2E ALL PASSED ===")

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
    defmodule PhaseAE2E.Buffer do
      @path "/tmp/pa_e2e_buffer.log"

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

    defmodule PhaseAE2E.Scenario do
      defstruct [:foreman, :router, :last_mark]

      def run(_report) do
        router = PhaseAE2E.Buffer.start()

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
        |> login("e2edriver", "阿福")
        |> command("score", "铜钱", "score-coins")
        |> command(["w", "n", "n", "e"], "张记铁铺", "walk-tiepupu")

        # 商店（A10/N2）
        |> command("list 店小二", "摊开货物", "shop-list")
        |> settle(400)
        |> command("买 包子", "买下包子", "buy-baozi")
        |> command("eat 包子", "吃下包子", "eat-baozi")

        # 问询（A10/N4）
        |> command("问 店小二 柳溪", "柳溪镇不大", "ask-liuxi")

        # 门派 v0（A11/N5）：拜师 + 学内功
        |> command(["w", "w"], "练武场", "walk-lianwuchang")

        # no_fight 房间拦截（A5/D2）：练武场不可动手
        |> command("杀 黑虎", "习武清修之地", "no-fight-block")
        |> command("kill 黑虎", "习武清修之地", "no-fight-en")

        |> command("apprentice 王重九", "柳溪派门下弟子", "apprentice")
        |> command("learn liuxi-neigong 王重九", "柳溪内功进步了", "learn-neigong")
        |> command("enable force liuxi-neigong", "作为内功", "enable-force")

        # jiali 手动档（A9/P6）：liuxi-neigong 1 级 → 上限 0 档，被拒
        |> command("jiali 3", "最多加力 0", "jiali-guard")

        # 打坐（A6/P3）：练武场是 no_fight 房，会被拒绝；回广场再打坐
        |> command("dazuo 30", "无法在这个地方安心打坐", "dazuo-blocked")
        |> command(["e"], "镇广场", "back-guangchang")
        |> command("打坐 30", "盘膝坐下", "dazuo-start")
        |> settle(3000)
        |> expect_seen("dazuo-finish", "运功完毕")
        |> command("pai", "门派贡献", "pai-info")

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

      defp settle(state, ms) do
        Process.sleep(ms)
        state
      end

      defp expect_seen(%{last_mark: mark} = state, label, text) do
        judge(state, label, mark, fn t -> String.contains?(t, text) end, 8000)
      end

      defp mark(), do: PhaseAE2E.Buffer.size()

      defp judge(state, label, mark, pred, timeout) do
        deadline = System.monotonic_time(:millisecond) + timeout
        do_judge(state, label, mark, pred, deadline)
      end

      defp do_judge(state, label, mark, pred, deadline) do
        text = PhaseAE2E.Buffer.since(mark)

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

    PhaseAE2E.Scenario.run(nil)
    """
  end
end

PhaseAE2E.Driver.run()
