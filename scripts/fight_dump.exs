# 诊断：开战后双方 tick 是否自续（结果直接落盘 /tmp/fight_dump.log）
defmodule FightDump.Driver do
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

    :rpc.block_call(node, Code, :eval_string, [cleanup, [], [file: "fd_cleanup"]])

    code = ~S"""
    File.rm("/tmp/fight_dump.log")
    log = fn s -> File.write("/tmp/fight_dump.log", s <> "\n", [:append]) end

    log.("== boot ==")

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
    end

    Process.sleep(500)
    type.("dumpuser")
    type.("pw")
    type.("探员")
    Process.sleep(1000)

    Enum.each(["w", "n"], fn c ->
      type.(c)
      Process.sleep(400)
    end)

    type.("kill 黑虎")
    Process.sleep(300)

    st0 = :sys.get_state(foreman)
    log.("t0.3 full: #{inspect(st0.character.meta.combat)}")

    Enum.each(1..4, fn i ->
      Process.sleep(1000)

      st = :sys.get_state(foreman)
      ch = st.character
      combat = ch.meta.combat

      log.("t#{i}: raw=#{inspect(combat, limit: 12)}")
    end)

    # NPC 侧状态
    Enum.each(DynamicSupervisor.which_children(Kantele.Character.Foreman.Supervisor), fn {_, pid, _, _} ->
      st = :sys.get_state(pid)
      ch = st.character

      case ch && ch.name do
        "黑虎" ->
          c = ch.meta.combat

          log.(
            "HEIHU: enemies=#{Enum.map(c.enemies, & &1.name)} busy=#{c.busy} " <>
              "queue=#{length(st.action_queue)}"
          )

        _ ->
          :ok
      end
    end)

    log.("== done ==")
    """

    case :rpc.block_call(node, Code, :eval_string, [code, [], [file: "fight_dump"]]) do
      {:done, _} -> :ok
      other -> IO.puts("EVAL #{inspect(other, limit: :infinity)}")
    end

    # 把游戏节点写好的日志读回来
    case :rpc.block_call(node, File, :read, ["/tmp/fight_dump.log"]) do
      {:ok, text} -> IO.puts(text)
      other -> IO.puts("READ #{inspect(other)}")
    end
  end
end

FightDump.Driver.run()
