defmodule InfoSmoke do
  def run() do
    stats = %Kantele.Character.Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 1120,
      potential: 160,
      skills: %{"force" => 20, "liuxi-neigong" => 5, "sword" => 5, "liuxin-jian" => 3, "dodge" => 60, "parry" => 40, "unarmed" => 60},
      mapped: %{"force" => "liuxi-neigong", "sword" => "liuxin-jian"}
    }

    conn = %Kalevala.Character.Conn{
      character: %Kalevala.Character{
        id: "x",
        name: "x",
        pid: self(),
        room_id: "r",
        meta: %Kantele.Character.PlayerMeta{
          vitals: Kantele.Character.Vitals.new(),
          stats: stats,
          combat: Kantele.Character.Combat.new()
        }
      },
      session: %{}
    }

    out = Kantele.Character.InfoCommand.run(conn, %{})

    Enum.each(out.output, fn
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: d}} ->
        IO.puts(IO.iodata_to_binary(d))

      _ ->
        :ok
    end)
  end
end

InfoSmoke.run()
