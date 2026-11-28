alias Kalevala.{Character.Conn, Event}
alias Kantele.Character.{PlayerMeta, Stats, Vitals, Combat}

c = %Kalevala.Character{
  id: "player:test",
  name: "测试玩家",
  room_id: "x",
  meta: %PlayerMeta{
    vitals: %Vitals{},
    stats: %Stats{weiwang: 0},
    combat: %Combat{},
    env: %{},
    temp: %{}
  }
}

conn = %Conn{character: c, private: %Conn.Private{channel_changes: []}, output: [], session: %{}}

r =
  Kantele.Character.Events.call(conn, %Event{
    topic: "npc/init/weiwang",
    from_pid: self(),
    data: %{weiwang: 15, npc_name: "庄允城"}
  })

IO.inspect(r.private.update_character, label: "routed")

direct =
  Kantele.Character.NpcInitEvent.weiwang(conn, %{
    data: %{weiwang: 15, npc_name: "庄允城"}
  })

IO.inspect(direct.private.update_character.meta.stats.weiwang, label: "direct weiwang")

 ultra_conn = %Conn{character: %{c | meta: %{c.meta | temp: %{"want_opinion/x" => 1}}}, private: %Conn.Private{channel_changes: []}, output: [], session: %{}}
ultra_r = Kantele.Character.Events.call(ultra_conn, %Event{topic: "ultra/init", from_pid: self(), data: %{clear_want_opinion: true}})
IO.inspect(ultra_r.private.update_character.meta.temp, label: "ultra routed")
