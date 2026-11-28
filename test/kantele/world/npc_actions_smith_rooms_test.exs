defmodule Kantele.World.NpcActions.SmithRoomsTest do
  @moduledoc """
  第 56 批：铁匠打工链按 LPC clone 推广到中原/苏州打铁铺。

  覆盖 `Kantele.World.NpcActions.Smith` 的广播房间取 `params.room_id`
  （不再写死 `xiangyang:tiejiangpu`），以及三间打铁铺的注册表接线
  （注册表断言在 `npc_action_handlers_test.exs`）。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.Smith

  defp conn(room_id) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: room_id,
        meta: %PlayerMeta{
          stats: %Stats{},
          vitals: %Vitals{qi: 100},
          temp: %{"smith/gu" => 1},
          marks: %{},
          coins: 1_000,
          combat: %Combat{}
        },
        inventory: []
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, verb, trailing \\ "") do
    %{verb: verb, trailing: trailing, room_id: room_id, npc: %Kalevala.Character{name: "铁匠"}}
  end

  defp channels(conn) do
    Enum.map(conn.private.channel_changes, fn
      {:publish, channel, _event, _opts, _fun} -> channel
      _ -> ""
    end)
  end

  for room <- ["city:datiepu", "suzhou:datiepu"] do
    test "#{room}：gu 领活后广播发到本房间，且 reward 正常结算" do
      room_id = unquote(room)
      result = Smith.run(conn(room_id), params(room_id, "gu"))

      assert "rooms:#{room_id}" in channels(result)
      refute Enum.any?(channels(result), &String.contains?(&1, "xiangyang:tiejiangpu"))

      updated = result.private.update_character || result.character
      assert updated.meta.temp == %{}
      assert updated.meta.coins > 1_000
      assert updated.meta.marks["mark/job_smith"] == 1
    end

    test "#{room}：repair 无参只回私聊，不广播到房间" do
      room_id = unquote(room)
      result = Smith.run(conn(room_id), params(room_id, "repair"))

      assert Enum.any?(result.output, &String.contains?(IO.iodata_to_binary(&1.data), "打算修理什么对象"))
      assert channels(result) == []
    end
  end
end
