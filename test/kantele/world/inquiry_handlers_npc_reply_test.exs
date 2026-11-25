defmodule Kantele.World.InquiryHandlers.NpcReplyTest do
  @moduledoc """
  `Kantele.World.InquiryHandlers.NpcReply` 的 #1045 少林道果服务型问询：
  检查 family == 少林派，设置 pending/daoguo_repair 临时标记，渲染「我们走罢！」。

  测试 `run/3` 行为。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.NpcReply

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "少林派", generation: 39})

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{combat_exp: 2000000, shen: 0, skills: %{}},
      family: family,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:damo_yuan",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Kalevala.Character.Conn.Text{data: data} -> data
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  defp base_config do
    %{"kind" => "npc_reply"}
  end

  defp base_data do
    %{asker_id: "player:test", npc_id: "shaolin:dao_guo", npc_name: "道果"}
  end

  describe "少林派检查" do
    test "family == 少林派：设置 pending/daoguo_repair，渲染「我们走罢！」" do
      conn0 = conn()
      config = base_config()
      data = base_data()

      result = NpcReply.run(conn0, config, data)

      assert output_text(result) =~ "我们走罢！"

      # 验证 temp 标记已设置（put_character 存入 private.update_character）
      character = result.private.update_character || result.character
      temp = Map.get(character.meta, :temp) || %{}
      assert Map.get(temp, :pending_daoguo_repair) == true
    end

    test "family != 少林派：返回拒绝文案，不设置标记" do
      conn0 = conn(family: %{name: "武当派", generation: 35})
      config = base_config()
      data = base_data()

      result = NpcReply.run(conn0, config, data)

      assert output_text(result) =~ "素无来往"

      character = result.private.update_character || result.character
      temp = Map.get(character.meta, :temp) || %{}
      assert Map.get(temp, :pending_daoguo_repair) != true
    end

    test "无 family：返回拒绝文案" do
      conn0 = conn(family: nil)
      config = base_config()
      data = base_data()

      result = NpcReply.run(conn0, config, data)

      assert output_text(result) =~ "素无来往"
    end
  end
end
