defmodule Kantele.Character.ImbueCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ImbueCommand
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
    Items.put("test:sword", %Item{
      id: "test:sword",
      name: "铁剑 Tiejian",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %{damage: 22, skill_type: "sword"}
    })

    Items.put("test:herb", %Item{
      id: "test:herb",
      name: "灵草 Lingcao",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %{magic: %{type: "fire", power: 5}}
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

  describe "路由解析" do
    test "imbue 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("imbue 灵草 in 铁剑")
      assert parsed.module == ImbueCommand
      assert parsed.params["arg"] == "灵草 in 铁剑"
    end

    test "imbue 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("imbue")
      assert parsed.module == ImbueCommand
    end
  end

  describe "imbue 命令" do
    test "没有武器时提示" do
      conn = ImbueCommand.run(build_conn(player([])), %{"arg" => "灵草 in 铁剑"})
      assert output_text(conn) =~ "你身上没有"
    end

    test "没有灵物时提示" do
      sword = instance("test:sword", "sword-1", %{})
      conn = ImbueCommand.run(build_conn(player([sword])), %{"arg" => "灵草 in 铁剑"})
      assert output_text(conn) =~ "你身上没有"
    end

    test "武器未圣化时拒绝" do
      sword = instance("test:sword", "sword-1", %{"owner" => %{"player-1" => "张三"}})
      herb = instance("test:herb", "herb-1", %{})
      conn = ImbueCommand.run(build_conn(player([sword, herb])), %{"arg" => "灵草 in 铁剑"})

      text = output_text(conn)
      assert text =~ "圣化" or text =~ "浸透"
    end

    test "格式错误时提示" do
      conn = ImbueCommand.run(build_conn(player([])), %{"arg" => "灵草 铁剑"})
      assert output_text(conn) =~ "imbue"
    end
  end
end
