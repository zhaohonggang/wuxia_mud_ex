defmodule RoomDupProbe do
  def run() do
    {:ok, hostname} = :inet.gethostname()
    node = String.to_atom("app@#{hostname}")
    true = Node.connect(node)

    code = ~S"""
    Enum.each(["liuxi:guangchang", "liuxi:shanlu"], fn room_id ->
      pid =
        case Kalevala.World.Room.global_name(room_id) do
          {:global, name} -> :global.whereis_name(name)
          _ -> nil
        end

      case pid do
        nil ->
          IO.puts("#{room_id}: room not found")

        pid ->
          st = :sys.get_state(pid)
          chars = st.private.characters

          IO.puts(
            "#{room_id}: #{length(chars)} chars -> " <>
              Enum.map_join(chars, ", ", fn c ->
                "#{c.name}##{String.slice(c.id, 0..5)}(#{inspect(c.pid)})"
              end)
          )
      end
    end)

    IO.puts("--- foremen ---")

    Enum.each(DynamicSupervisor.which_children(Kantele.Character.Foreman.Supervisor), fn {_, pid, _, _} ->
      st = :sys.get_state(pid)
      ch = st.character

      if ch && ch.meta && Map.has_key?(ch.meta, :combat_config) do
        cfg = ch.meta.combat_config
        IO.puts("NPC #{ch.name} room=#{ch.room_id} spawn=#{cfg.spawn_room_id} pid=#{inspect(pid)}")
      end
    end)
    """

    case :rpc.block_call(node, Code, :eval_string, [code, [], [file: "dup_probe"]]) do
      {:ok, _, _} -> :ok
      other -> IO.puts("EVAL #{inspect(other, limit: 600)}")
    end
  end
end

RoomDupProbe.run()
