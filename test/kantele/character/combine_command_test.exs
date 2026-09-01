defmodule Kantele.Character.CombineCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.CombineCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kalevala.World.Item
  alias Kantele.World.Items

  @clone_verb %Kalevala.Verb{
    key: :clone,
    icon: "clone",
    text: "克隆",
    send: "clone ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  setup do
    Items.put("test:herb1", %Item{
      id: "test:herb1",
      name: "灵草一 Lingcao1",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    Items.put("test:herb2", %Item{
      id: "test:herb2",
      name: "灵草二 Lingcao2",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    :ok
  end

  defp player(inventory \\ [], opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000)
    }

    stats = %Stats{
      skills: Keyword.get(opts, :skills, %{"force" => 350})
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp instance(item_id, id \\ nil, meta \\ %{}) do
    %{
      id: id || "instance-#{item_id}-#{:rand.uniform(9999)}",
      item_id: item_id,
      meta: meta,
      created_at: DateTime.utc_now()
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_inventory(conn),
    do: (conn.private.update_character || conn.character).inventory

  describe "路由解析" do
    test "combine 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("combine 灵草一 & 灵草二")
      assert parsed.module == CombineCommand
      assert parsed.params["arg"] == "灵草一 & 灵草二"
    end

    test "combine 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("combine")
      assert parsed.module == CombineCommand
    end
  end

  describe "combine 命令" do
    test "没有材料时提示" do
      conn = CombineCommand.run(build_conn(player([])), %{"arg" => "灵草一 & 灵草二"})
      assert output_text(conn) =~ "没有"
    end

    test "材料不足时提示" do
      herb1 = instance("test:herb1", "herb1-1")
      conn = CombineCommand.run(build_conn(player([herb1])), %{"arg" => "灵草一 & 灵草二"})
      assert output_text(conn) =~ "没有" or output_text(conn) =~ "材料"
    end

    test "精力不足时提示" do
      herb1 = instance("test:herb1", "herb1-1")
      herb2 = instance("test:herb2", "herb2-1")
      p = player([herb1, herb2], jingli: 10, max_jingli: 2000)
      conn = CombineCommand.run(build_conn(p), %{"arg" => "灵草一 & 灵草二"})
      assert output_text(conn) =~ "精力"
    end
  end
end
