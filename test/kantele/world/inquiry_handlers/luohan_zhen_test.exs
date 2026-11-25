defmodule Kantele.World.InquiryHandlers.LuohanZhenTest do
  @moduledoc """
  十八罗汉大阵问询处理器测试（kind = "luohan_zhen"），对应 LPC
  `kungfu/class/shaolin/xuan-ku.c` / `xuan-nan.c` 的 ask_me。

  覆盖：
  - kind 注册（InquiryHandlers.lookup）
  - NPC 未找到时的文案渲染

  状态机门控（技能、辈份、有罪、已闯过等）已在
  `test/kantele/world/luohan_zhen_test.exs` 全量覆盖，此处不重复。
  """

  use ExUnit.Case, async: true

  import Enum

  alias Kalevala.Character.Conn
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.LuohanZhen

  defp conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp fighter(overrides \\ %{}) do
    %{
      id: "player:test",
      name: "测试玩家",
      room_id: "shaolin:wuchang",
      meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{},
        temp: %{}
      }
    } |> Map.merge(Map.new(overrides))
  end

  defp data(npc_id, overrides \\ %{}) do
    %{
      kind: "luohan_zhen",
      config: %{kind: "luohan_zhen"},
      npc_id: npc_id,
      npc_name: "玄苦大师",
      npc_room_id: "shaolin:wuchang",
      asker_id: "player:test"
    } |> Map.merge(Map.new(overrides))
  end

  describe "run/3" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert InquiryHandlers.lookup("luohan_zhen") == LuohanZhen
    end

    test "NPC 未找到 → 渲染「这里没有这位长老」" do
      c = conn(fighter())
      conn2 = LuohanZhen.run(c, %{kind: "luohan_zhen"}, data("nonexistent_npc_id"))

      assert any?(
        conn2.output,
        fn entry -> String.contains?(entry.data, "这里没有这位长老") end
      )
    end
  end
end
