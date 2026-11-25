defmodule Kantele.World.RoomItemInit.ShaolinTest do
  @moduledoc """
  `Kantele.World.RoomItemInit` 少林金刚伏魔圈入口：进入 `shaolin:fumoquan` 时，
  少林辈分 <= 36 的玩家置位 `valid_in_fumoquan` temp 标记，供三老 ask_me 门控使用。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.RoomItemInit

  @fumoquan "shaolin:fumoquan"

  defp shaolin_player(gen \\ 35) do
    %Kalevala.Character{
      id: "player:1",
      name: "玩家",
      pid: self(),
      room_id: @fumoquan,
      inventory: [],
      meta: %PlayerMeta{
        vitals: %Vitals{jing: 300, qi: 500, max_jing: 300, max_qi: 500},
        stats: %Stats{str: 20, dex: 20, con: 20, int: 20, skills: %{}, mapped: %{}},
        combat: Kantele.Character.Combat.new(),
        family: %{name: "少林派", generation: gen},
        temp: %{}
      }
    }
  end

  defp conn(character \\ shaolin_player()), do: build_conn(character)

  defp temp_of(conn) do
    character = conn.private.update_character || conn.character
    case Map.get(character.meta || %{}, :temp) do
      nil -> %{}
      temp -> temp
    end
  end

  test "少林辈分 <= 36 进入 fumoquan：置位 valid_in_fumoquan = 1" do
    conn = RoomItemInit.on_enter(conn(), @fumoquan, fn _room_id, _keyword -> false end)

    assert temp_of(conn) == %{"valid_in_fumoquan" => 1}
  end

  test "少林辈分 = 36 边界：置位 valid_in_fumoquan = 1" do
    conn = RoomItemInit.on_enter(conn(shaolin_player(36)), @fumoquan, fn _room_id, _keyword -> false end)

    assert temp_of(conn) == %{"valid_in_fumoquan" => 1}
  end

  test "少林辈分 = 37 不置位：超过上限" do
    conn = RoomItemInit.on_enter(conn(shaolin_player(37)), @fumoquan, fn _room_id, _keyword -> false end)

    assert temp_of(conn) == %{}
  end

  test "非少林派进入 fumoquan：不置位" do
    other = %{
      shaolin_player(35)
      | meta: %{shaolin_player(35).meta | family: %{name: "武当派", generation: 1}}
    }

    conn = RoomItemInit.on_enter(conn(other), @fumoquan, fn _room_id, _keyword -> false end)

    assert temp_of(conn) == %{}
  end

  test "无 family 的玩家进入 fumoquan：不置位" do
    no_family = %{shaolin_player(35) | meta: %{shaolin_player(35).meta | family: nil}}

    conn = RoomItemInit.on_enter(conn(no_family), @fumoquan, fn _room_id, _keyword -> false end)

    assert temp_of(conn) == %{}
  end

  test "其它房间不触发 fumoquan 逻辑" do
    other_room = %{shaolin_player(35) | room_id: "shaolin:guangchang1"}

    conn = RoomItemInit.on_enter(conn(other_room), "shaolin:guangchang1", fn _room_id, _keyword -> false end)

    assert temp_of(conn) == %{}
  end
end
