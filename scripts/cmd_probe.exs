defmodule CmdProbe do
  def run() do
    IO.puts("exported run/2: #{function_exported?(Kantele.Character.CommandsCommand, :run, 2)}")

    conn = %Kalevala.Character.Conn{
      character: %Kalevala.Character{
        id: "x",
        name: "x",
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

    out = Kantele.Character.CommandsCommand.run(conn, %{})
    IO.puts("output items: #{length(out.output)}")

    Enum.each(out.output, fn
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: d}} ->
        IO.puts(IO.iodata_to_binary(d))

      other ->
        IO.puts("OTHER #{String.slice(inspect(other), 0, 100)}")
    end)
  end
end

CmdProbe.run()
