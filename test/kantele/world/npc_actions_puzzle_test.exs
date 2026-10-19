defmodule Kantele.World.NpcActions.PuzzleTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.World.NpcActions.Puzzle

  defp npc(name), do: %Kalevala.Character{name: name}

  defp conn(room_id) do
    %Conn{
      character: %Kalevala.Character{name: "玩家", room_id: room_id},
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  describe "run/2（无 curl/AppKey 的降级分支）" do
    test "无参数 puzzle → 提示「迷题还在整理中」并返回 conn" do
      npc = npc("李瘦辞")
      conn2 = Puzzle.run(conn("beijing:wenmiao"), %{verb: "puzzle", trailing: "", room_id: "beijing:wenmiao", npc: npc})

      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "迷题还在整理中")
      # 只私发玩家，不广播
      assert conn2.private.channel_changes == []
    end

    test "带参数 puzzle <答案> → 同样降级（API 未部署，arg 分支不可达）" do
      npc = npc("李瘦辞")
      conn2 = Puzzle.run(conn("beijing:wenmiao"), %{verb: "puzzle", trailing: "月光", room_id: "beijing:wenmiao", npc: npc})

      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "迷题还在整理中")
    end
  end
end
