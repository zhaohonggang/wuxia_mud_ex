defmodule CommandsSmoke do
  def run() do
    conn = %Kalevala.Character.Conn{
      character: %Kalevala.Character{
        id: "t",
        name: "t",
        pid: self(),
        room_id: "r",
        meta: %Kantele.Character.PlayerMeta{
          vitals: Kantele.Character.Vitals.new(),
          stats: Kantele.Character.Stats.new(),
          combat: Kantele.Character.Combat.new()
        }
      },
      session: %{}
    }

    case Kantele.Character.Commands.call(conn, "commands") do
      {:error, :unknown} ->
        IO.puts("UNKNOWN COMMAND")

      conn ->
        IO.puts("== commands output ==")

        Enum.each(conn.output, fn
          %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: d}} ->
            IO.puts(IO.iodata_to_binary(d))

          other ->
            IO.puts("OTHER " <> String.slice(inspect(other), 0, 80))
        end)
    end

    # 中文别名
    conn2 = Kantele.Character.Commands.call(build_conn(conn.character), "命令")

    case conn2 do
      {:error, :unknown} -> IO.puts("中文别名 FAILED")
      _ -> IO.puts("中文别名 OK")
    end
  end

  defp build_conn(character) do
    %Kalevala.Character.Conn{character: character, session: %{}}
  end
end

CommandsSmoke.run()
