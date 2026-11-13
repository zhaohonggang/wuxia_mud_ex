defmodule Kantele.NPC.MengpoTest do
  @moduledoc """
  孟婆 NPC 问询处理器定向测试。

  覆盖：ask_specs 关键字包含 "孟婆汤"（对应 UCL inquiries 配置）
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.NPC.Mengpo

  defp ghost(opts \\ []) do
    %Character{
      id: Keyword.get(opts, :id, "ghost-mengpo"),
      name: Keyword.get(opts, :name, "游魂"),
      pid: self(),
      room_id: "death:gate",
      inventory: [],
      meta: %PlayerMeta{
        env: %{ghost: true},
        stats: %{combat_exp: 20_000_000}
      }
    }
  end

  defp npc(), do: %{id: "mengpo", name: "孟婆", pid: self(), room_id: "death:gate"}

  describe "Mengpo.ask_specs/0 关键字覆盖" do
    test "包含 \"孟婆汤\" 关键字（对应 UCL inquiries）" do
      specs = Mengpo.ask_specs()
      assert specs["孟婆汤"] != nil
    end

    test "包含 \"汤\" 关键字" do
      specs = Mengpo.ask_specs()
      assert specs["汤"] != nil
    end

    test "包含 \"喝汤\" 关键字" do
      specs = Mengpo.ask_specs()
      assert specs["喝汤"] != nil
    end

    test "包含 \"tang\" 关键字" do
      specs = Mengpo.ask_specs()
      assert specs["tang"] != nil
    end

    test "包含 \"mengpo_tang\" 关键字" do
      specs = Mengpo.ask_specs()
      assert specs["mengpo_tang"] != nil
    end
  end

  describe "Mengpo.check/3 幽灵态与等级门控" do
    test "非幽灵态拒绝" do
      asker = %Character{
        id: "p-living",
        name: "活人",
        pid: self(),
        meta: %PlayerMeta{env: %{ghost: false}}
      }
      assert {:error, msg} = Mengpo.check(asker, npc(), "孟婆汤")
      assert msg =~ "阳人喝什么孟婆汤"
    end

    test "幽灵态且等级达标放行" do
      asker = ghost()
      assert :ok = Mengpo.check(asker, npc(), "孟婆汤")
    end
  end
end
