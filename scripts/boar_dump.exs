# 诊断：杀野猪全流程——玩家收到的每一行 + 野猪进程状态（结果落盘 /tmp/boar_dump.log）
defmodule BoarDump.Driver do
  def run() do
    {:ok, hostname} = :inet.gethostname()
    node = String.to_atom("app@#{hostname}")
    true = Node.connect(node)

    cleanup = """
    supervisor = Kantele.Character.Foreman.Supervisor

    DynamicSupervisor.which_children(supervisor)
    |> Enum.each(fn {_, pid, _, _} -> DynamicSupervisor.terminate_child(supervisor, pid) end)

    Kantele.World.Kickoff.reload()
    """

    :rpc.block_call(node, Code, :eval_string, [cleanup, [], [file: "bd_c"]])

    code = ~S"""
    defmodule BoarDump.Scenario do
      defp log(s), do: File.write("/tmp/boar_dump.log", s <> "\n", [:append])

      def run(_report) do
        File.rm("/tmp/boar_dump.log")
        log("== boot ==")

        {:ok, foreman} =
          Kalevala.Character.Foreman.start_player(self(),
            supervisor_name: Kantele.Character.Foreman.Supervisor,
            communication_module: Kantele.Communication,
            initial_controller: Kantele.Character.LoginController,
            presence_module: Kantele.Character.Presence,
            quit_view: {Kantele.Character.QuitView, "disconnected"},
            protocol: self()
          )

        type = fn line ->
          send(foreman, {:recv, :text, line})
          Process.sleep(300)
          drain_to_log()
        end

        wait_and_log = fn ms ->
          Process.sleep(ms)
          drain_to_log()
        end

        drain_to_log()

        Process.sleep(500)
        type.("dumpuser")
        type.("pw")
        type.("探员")
        Process.sleep(1200)

        Enum.each(["w", "n", "n"], fn c ->
          type.(c)
          Process.sleep(500)
        end)

        log("== KILL ==")
        type.("kill 野猪")

        Enum.each(1..10, fn i ->
          wait_and_log.(1000)
        end)

        Enum.each(DynamicSupervisor.which_children(Kantele.Character.Foreman.Supervisor), fn {_, pid, _, _} ->
          st = :sys.get_state(pid)
          ch = st.character

          case ch && ch.name do
            "野猪" ->
              c = ch.meta.combat

              log(
                "BOAR: alive=#{Process.alive?(pid)} enemies=#{Enum.map(c.enemies, & &1.name)} " <>
                  "busy=#{c.busy} queue=#{length(st.action_queue)} proc=#{!!st.processing_action} " <>
                  "controller=#{inspect(st.controller)}"
              )

            n when is_binary(n) ->
              log("OTHER-ALIVE: #{n}")

            _ ->
              :ok
          end
        end)

        log("== done ==")
      end

      defp drain_to_log do
        receive do
          {:send, out} ->
            case out do
              %{text: %Kalevala.Character.Conn.Text{data: d}} ->
                log("OUT| " <> IO.iodata_to_binary(d))

              other ->
                log("RAW| " <> String.slice(inspect(other), 0, 110))
            end

            drain_to_log()

          _ ->
            drain_to_log()
        after
          0 ->
            :ok
        end
      end
    end

    BoarDump.Scenario.run(nil)
    """

    case :rpc.block_call(node, Code, :eval_string, [code, [], [file: "boar_dump"]]) do
      {:done, _} -> :ok
      other -> IO.puts("EVAL #{inspect(other, limit: 800)}")
    end

    case :rpc.block_call(node, File, :read, ["/tmp/boar_dump.log"]) do
      {:ok, text} -> IO.puts(text)
      other -> IO.puts("READ #{inspect(other)}")
    end
  end
end

BoarDump.Driver.run()
