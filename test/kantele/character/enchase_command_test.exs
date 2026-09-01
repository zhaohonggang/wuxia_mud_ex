defmodule Kantele.Character.EnchaseCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.EnchaseCommand
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

    Items.put("test:gem", %Item{
      id: "test:gem",
      name: "蓝宝石 Lanbaoshi",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %{can_be_enchased: true, magic: %{type: "magic", power: 20}, weight: 1}
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
      skills: Keyword.get(opts, :skills, %{"certosina" => 250, "force" => 350})
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
    test "enchase 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("enchase 蓝宝石 in 铁剑")
      assert parsed.module == EnchaseCommand
      assert parsed.params["arg"] == "蓝宝石 in 铁剑"
    end

    test "enchase 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("enchase")
      assert parsed.module == EnchaseCommand
    end
  end

  describe "enchase 命令" do
    test "没有武器时提示" do
      conn = EnchaseCommand.run(build_conn(player([])), %{"arg" => "蓝宝石 in 铁剑"})
      assert output_text(conn) =~ "你身上没有"
    end

    test "没有宝石时提示" do
      sword = instance("test:sword", "sword-1", %{})
      conn = EnchaseCommand.run(build_conn(player([sword])), %{"arg" => "蓝宝石 in 铁剑"})
      assert output_text(conn) =~ "你身上没有"
    end

    test "武器未浸透时拒绝" do
      sword = instance("test:sword", "sword-1", %{})
      gem = instance("test:gem", "gem-1", %{})
      conn = EnchaseCommand.run(build_conn(player([sword, gem])), %{"arg" => "蓝宝石 in 铁剑"})

      text = output_text(conn)
      assert text =~ "浸透" or text =~ "镶嵌"
    end

    test "镶嵌技艺不够时拒绝" do
      sword = instance("test:sword", "sword-1", %{})
      gem = instance("test:gem", "gem-1", %{})
      p = player([sword, gem], skills: %{"certosina" => 100, "force" => 350})
      conn = EnchaseCommand.run(build_conn(p), %{"arg" => "蓝宝石 in 铁剑"})

      assert output_text(conn) =~ "镶嵌"
    end
  end
end
