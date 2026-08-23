# 战斗系统端到端验收（连接游戏节点，进程内驱动真实 Foreman）
#
# 运行：
#   docker exec wuxia_mud_dev-app-1 sh -c \
#     "cd /app && elixir --sname probe -S mix run --no-start scripts/combat_e2e.exs"
#
# 原理：app 容器以 `--sname app` 启动（Erlang 分布），本脚本 Node.connect 进
# 游戏 VM，:rpc 求值场景代码——场景以一个独立 Router 进程充当 telnet 协议
# 进程接收全部输出并落盘缓冲；断言采用「先打标记、后动作、匹配标记之后的
# 文件增量」，与 telnet 版冒烟脚本同一套经过验证的机制。

defmodule CombatE2E.Driver do
  def run() do
    {:ok, hostname} = :inet.gethostname()
    node = String.to_atom("app@#{hostname}")

    case Node.connect(node) do
      true -> IO.puts("connected to #{node}")
      reason -> IO.puts("FAILED to connect #{node}: #{inspect(reason)}")
    end

    # 预清理：杀掉历史测试遗留的玩家 foreman，并重载世界恢复房间物品/NPC 状态
    cleanup_code = """
    supervisor = Kantele.Character.Foreman.Supervisor

    DynamicSupervisor.which_children(supervisor)
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(supervisor, pid)
    end)

    Kantele.World.Kickoff.reload()
    """

    :rpc.block_call(node, Code, :eval_string, [cleanup_code, [], [file: "e2e_cleanup"]])

    me_b64 = self() |> :erlang.term_to_binary() |> Base.encode64()

    code = String.replace(scenario_code(), "__REPORT_B64__", me_b64)

    case :rpc.block_call(node, Code, :eval_string, [code, [], [file: "combat_e2e"]]) do
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
        IO.puts("\n=== ALL E2E TESTS PASSED ===")

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

  # ---- 在游戏节点内求值的场景代码 ----

  defp scenario_code() do
    ~S"""
    defmodule CombatE2E.Buffer do
      @path "/tmp/e2e_buffer.log"

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

      defp append(text) do
        File.write(@path, text, [:append])
      end

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

    defmodule CombatE2E.Scenario do
      defstruct [:foreman, :router, :last_mark, failures: []]

      defp rep(state, label, ok) do
        send(:erlang.binary_to_term(Base.decode64!("__REPORT_B64__")), {:e2e, label, ok})
        state
      end

      def run(_report) do
        router = CombatE2E.Buffer.start()

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
        |> login("e2edriver", "铁蛋")
        |> command("score", "实战经验", "score")
        |> command(["w", "n", "n", "e"], "张记铁铺", "walk-tiepupu")
        |> command("get 长剑", "长剑 Changjian", "get-sword")
        |> command("wield 长剑", "抽出一柄长剑", "wield-sword")
        |> command(["get 布袍", "wear 布袍"], "穿上了一件布袍", "wear-cloth")
        |> command(["w", "w"], "练武场", "walk-lianwuchang")
        |> burst("learn force 王重九", 25)
        |> settle(1200)
        |> expect_seen("learn-force", "基本内功")
        |> command("enable force liuxi-neigong", "作为内功", "enable-force")
        |> burst("learn liuxi-neigong 王重九", 3)
        |> settle(800)
        |> command("exert powerup", "柳溪内功", "exert-powerup")
        |> command("exert powerup", "已经在运功中了", "exert-twice")
        |> burst("learn sword 王重九", 4)
        |> burst("learn liuxin-jian 王重九", 1)
        |> settle(800)
        |> command("perform liuxin-jian.liu", "谈何施展", "perform-gate")
        |> command(["e", "s"], "想杀死你", "heihu-aggro")
        |> settle(4500)
        |> expect_seen("combat-rounds", "黑虎")
        |> command(["halt", "s"], nil, "flee")
        |> settle(1500)
        |> command("n", nil, "back-shanlu")
        |> command("kill 黑虎", nil, "kill-heihu")
        |> wait_text("清醒了过来", 150_000, "death-respawn")
        |> command("look", "城镇广场", "respawn-at-start")
         |> command("wield 长剑", "抽出", "rewield-sword")
         |> command(["w", "n"], nil, "to-yezhu")
        |> command("kill 野猪", nil, "kill-yezhu")
        |> wait_text("点实战经验", 90_000, "kill-reward")

        rep_send_done()
      rescue
        e ->
          rep_send_crash(Exception.format(:error, e, __STACKTRACE__))
      end

      defp rep_send_done, do: report_pid() |> send({:e2e_done, :ok})

      defp rep_send_crash(fmt) do
        report_pid() |> send({:e2e_done, fmt})
      end

      defp report_pid do
        :erlang.binary_to_term(Base.decode64!("__REPORT_B64__"))
      end

      # ---- 登录：走真实 LoginController 三步握手 ----

      defp login(state, username, charname) do
        Process.sleep(800)
        mark = mark()

        send(state.foreman, {:recv, :text, username})
        Process.sleep(300)
        send(state.foreman, {:recv, :text, "anypassword"})
        Process.sleep(300)
        send(state.foreman, {:recv, :text, charname})

        state
        |> judge("login", mark, fn text -> String.contains?(text, "> ") end, 25_000)
      end

      defp command(state, cmds, pattern, label) do
        mark = mark()

        Enum.each(List.wrap(cmds), fn cmd ->
          send(state.foreman, {:recv, :text, cmd})
          Process.sleep(350)
        end)

        case pattern do
          nil ->
            settle(state, 500)

          pattern ->
            judge(state, label, mark, fn text -> String.contains?(text, pattern) end, 15_000)
        end
      end

      defp burst(state, cmd, n) do
        mark = mark()

        Enum.each(1..n, fn _ ->
          send(state.foreman, {:recv, :text, cmd})
          Process.sleep(120)
        end)

        Map.put(state, :last_mark, mark)
      end

      defp settle(state, ms) do
        Process.sleep(ms)
        state
      end

      defp expect_seen(%{last_mark: mark} = state, label, text) do
        judge(state, label, mark, fn t -> String.contains?(t, text) end, 2000)
      end

      defp wait_text(state, text, timeout, label) do
        mark = mark()
        judge(state, label, mark, fn t -> String.contains?(t, text) end, timeout)
      end

      defp mark(), do: CombatE2E.Buffer.size()

      defp judge(state, label, mark, pred, timeout) do
        deadline = System.monotonic_time(:millisecond) + timeout
        do_judge(state, label, mark, pred, deadline)
      end

      defp do_judge(state, label, mark, pred, deadline) do
        text = CombatE2E.Buffer.since(mark)

        cond do
          pred.(text) ->
            send_report(label, true)
            state

          System.monotonic_time(:millisecond) > deadline ->
            send_report(label, false)
            state

          true ->
            Process.sleep(250)
            do_judge(state, label, mark, pred, deadline)
        end
      end

      defp send_report(label, ok) do
        send(
          :erlang.binary_to_term(Base.decode64!("__REPORT_B64__")),
          {:e2e, label, ok}
        )
      end
    end

    CombatE2E.Scenario.run(nil)
    """
  end
end

CombatE2E.Driver.run()
