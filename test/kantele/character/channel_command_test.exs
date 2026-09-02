defmodule Kantele.Character.ChannelCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ChannelCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  describe "general 频道" do
    test "发布消息" do
      p = player()
      conn = ChannelCommand.general(build_conn(p), %{"text" => "大家好"})

      changes = Enum.filter(conn.private.channel_changes, fn change ->
        elem(change, 0) == :publish && elem(change, 1) == "general"
      end)

      assert length(changes) == 1
    end

    test "general 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("general 大家好")
      assert parsed.module == ChannelCommand
      assert parsed.function == :general
    end
  end
end