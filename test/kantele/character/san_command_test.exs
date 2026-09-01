defmodule Kantele.Character.SanCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.SanCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.Item.Craft
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

    Items.put("test:blade", %Item{
      id: "test:blade",
      name: "大刀 Dadao",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %{damage: 30, skill_type: "blade"}
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
    test "san 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("san 铁剑")
      assert parsed.module == SanCommand
      assert parsed.params["arg"] == "铁剑"
    end

    test "san 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("san")
      assert parsed.module == SanCommand
    end
  end

  describe "san 命令" do
    test "没有武器时提示" do
      conn = SanCommand.run(build_conn(player([])), %{"arg" => "铁剑"})
      assert output_text(conn) =~ "你身上没有"
    end

    test "找不到指定武器时提示" do
      conn = SanCommand.run(build_conn(player([instance("test:sword")])), %{"arg" => "大刀"})
      assert output_text(conn) =~ "你身上没有"
    end

    test "圣化成功" do
      sword = instance("test:sword", "sword-1", %{"craft" => %{"owner" => %{"player-1" => "张三"}}})
      p = player([sword], neili: 9000, max_neili: 10000, jingli: 1900, max_jingli: 2000, skills: %{"force" => 350})
      conn = SanCommand.run(build_conn(p), %{"arg" => "铁剑"})

      text = output_text(conn)
      assert text =~ "圣化" or text =~ "运用"
    end

    test "内力不足时拒绝" do
      sword = instance("test:sword", "sword-1", %{"craft" => %{"owner" => %{"player-1" => "张三"}}})
      p = player([sword], neili: 1000, max_neili: 10000, jingli: 1900, max_jingli: 2000, skills: %{"force" => 350})
      conn = SanCommand.run(build_conn(p), %{"arg" => "铁剑"})

      assert output_text(conn) =~ "内力"
    end

    test "精力不足时拒绝" do
      sword = instance("test:sword", "sword-1", %{"craft" => %{"owner" => %{"player-1" => "张三"}}})
      p = player([sword], neili: 9000, max_neili: 10000, jingli: 100, max_jingli: 2000, skills: %{"force" => 350})
      conn = SanCommand.run(build_conn(p), %{"arg" => "铁剑"})

      assert output_text(conn) =~ "精力"
    end

    test "内功根基不够时拒绝" do
      sword = instance("test:sword", "sword-1", %{"craft" => %{"owner" => %{"player-1" => "张三"}}})
      p = player([sword], neili: 9000, max_neili: 10000, jingli: 1900, max_jingli: 2000, skills: %{"force" => 100})
      conn = SanCommand.run(build_conn(p), %{"arg" => "铁剑"})

      assert output_text(conn) =~ "内功"
    end
  end
end
