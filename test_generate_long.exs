Code.require_file("lib/kantele/world/room/qianting.ex", __DIR__)

room = %{
  state: %{
    gate: :close,
    exits: ["south", "east", "west"],
    laopu_present: true,
    laopu_living: true,
    laopu_owner_id: "player:owner",
    laopu_owner_permits: []
  }
}

result = Kantele.World.Room.Qianting.generate_long("Base long.\n", room, true)
IO.puts("Result: #{result}")
IO.puts("Contains: " <> (String.contains?(result, "老仆人扫扫") |> to_string()))
