defmodule Kantele.Character.RideCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.RideCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.UnrideCommand
  alias Kantele.Character.Vitals
  alias Kalevala.World.Item

  defp player(inventory \\ []) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
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

  defp mount_item do
    %Item{
      id: "test:horse",
      name: "千里马",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"ridable" => true}
    }
  end

  defp normal_item do
    %Item{id: "test:sword", name: "长剑", verbs: [], callback_module: Kantele.World.Item, meta: %{}}
  end

  defp instance(item) do
    %Item.Instance{id: "inst-1", item_id: item.id, item: item, created_at: DateTime.utc_now()}
  end

  describe "ride 上马" do
    test "空参数提示" do
      conn = RideCommand.run(build_conn(player()), %{"rest" => ""})
      assert output_text(conn) =~ "骑什么东西"
    end

    test "背包没有此坐骑提示" do
      conn = RideCommand.run(build_conn(player()), %{"rest" => "千里马"})
      assert output_text(conn) =~ "没有这样的坐骑"
    end

    test "非坐骑物品不能骑" do
      conn = RideCommand.run(build_conn(player([instance(normal_item())])), %{"rest" => "长剑"})
      assert output_text(conn) =~ "没有这样的坐骑"
    end

    test "骑上坐骑设置 meta.riding" do
      conn = RideCommand.run(build_conn(player([instance(mount_item())])), %{"rest" => "千里马"})
      updated = conn.private.update_character || conn.character
      assert updated.meta.riding.item_id == "test:horse"
      assert output_text(conn) =~ "跃上"
    end

    test "已有坐骑拒绝再骑" do
      char = %{
        player([instance(mount_item())])
        | meta: %{player([instance(mount_item())]).meta | riding: %{item_id: "test:horse"}}
      }

      conn = RideCommand.run(build_conn(char), %{"rest" => "千里马"})
      assert output_text(conn) =~ "已经有座骑"
    end
  end

  describe "unride 下马" do
    test "无坐骑提示" do
      conn = UnrideCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "根本就没座骑"
    end

    test "下马清除 riding" do
      char = %{player() | meta: %{player().meta | riding: %{item_id: "test:horse", name: "千里马"}}}
      conn = UnrideCommand.run(build_conn(char), %{})
      updated = conn.private.update_character || conn.character
      assert updated.meta.riding == nil
      assert output_text(conn) =~ "跳下"
    end
  end

  test "ride/unride 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("ride 千里马")
    assert parsed.module == Kantele.Character.RideCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("骑马 千里马")
    assert parsed.module == Kantele.Character.RideCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("unride")
    assert parsed.module == Kantele.Character.UnrideCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("下马")
    assert parsed.module == Kantele.Character.UnrideCommand
  end
end
