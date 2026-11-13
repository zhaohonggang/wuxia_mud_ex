defmodule Kantele.NPC.NiutouTest do
  @moduledoc """
  牛头 NPC 问询处理器定向测试。

  覆盖：
  - 幽灵态门控：非幽灵态拒绝，幽灵态放行
  - 关键字分派："还阳" / "奈河桥" / "牛头" / "niutou" / 未知关键字
  - execute 返回的消息内容
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.NPC.Niutou

  defp ghost(opts \\ []) do
    %Character{
      id: Keyword.get(opts, :id, "ghost-niutou"),
      name: Keyword.get(opts, :name, "游魂"),
      pid: self(),
      room_id: "death:gate",
      inventory: [],
      meta: %PlayerMeta{
        env: %{ghost: true}
      }
    }
  end

  defp living(opts \\ []) do
    %Character{
      id: Keyword.get(opts, :id, "player-living"),
      name: Keyword.get(opts, :name, "活人"),
      pid: self(),
      room_id: "city:wumiao",
      inventory: [],
      meta: %PlayerMeta{
        env: %{ghost: false}
      }
    }
  end

  defp npc(), do: %{id: "niutou", name: "牛头", pid: self(), room_id: "death:gate"}

  describe "Niutou.check/3 幽灵态门控" do
    test "非幽灵态（阳人）被拒绝" do
      asker = living()
      assert {:error, msg} = Niutou.check(asker, npc(), "还阳")
      assert msg =~ "阳人"
      assert msg =~ "冥府不容你在此久留"
    end

    test "幽灵态（游魂）放行" do
      asker = ghost()
      assert :ok = Niutou.check(asker, npc(), "还阳")
    end
  end

  describe "Niutou.execute/3 关键字分派" do
    test "「还阳」：拒绝并告知找白无常" do
      asker = ghost()
      {:ok, msg} = Niutou.execute(asker, npc(), "还阳")
      assert msg =~ "白无常"
      assert msg =~ "ask 白无常 还阳"
    end

    test "「奈河桥」：冷冰回应" do
      asker = ghost()
      {:ok, msg} = Niutou.execute(asker, npc(), "奈河桥")
      assert msg =~ "奈河桥"
      assert msg =~ "游魂"
    end

    test "「牛头」：冷冰回应" do
      asker = ghost()
      {:ok, msg} = Niutou.execute(asker, npc(), "牛头")
      assert msg =~ "把关"
    end

    test "「niutou」：与「牛头」等效" do
      asker = ghost()
      {:ok, msg1} = Niutou.execute(asker, npc(), "牛头")
      {:ok, msg2} = Niutou.execute(asker, npc(), "niutou")
      assert msg1 == msg2
    end

    test "未知关键字返回错误" do
      asker = ghost()
      assert {:error, _} = Niutou.execute(asker, npc(), "未知关键字")
    end

    test "ask_specs 包含全部四个关键字" do
      specs = Niutou.ask_specs()
      assert map_size(specs) == 4
      assert specs["还阳"] != nil
      assert specs["奈河桥"] != nil
      assert specs["牛头"] != nil
      assert specs["niutou"] != nil
    end
  end

  describe "Niutou.effects/3" do
    test "返回空列表" do
      asker = ghost()
      assert [] = Niutou.effects(asker, npc(), "还阳")
    end
  end
end
