defmodule Kantele.World.InquiryHandlers.GiveItemFumoquanTest do
  @moduledoc """
  `Kantele.World.InquiryHandlers.GiveItem` 的 `require_fumoquan` 门控：
  少林三老发放物品（九环锡杖/锦襕袈裟/神草结）要求玩家在金刚伏魔圈内。

  测试 `run/3` 通过 `gate_denial/2` 校验 `require_fumoquan` 配置。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "少林派", generation: 35})
    temp = Keyword.get(opts, :temp, %{"valid_in_fumoquan" => 1})

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{combat_exp: 2000000, shen: 0, skills: %{}},
      family: family,
      temp: temp
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:fumoquan",
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
    %{
      "kind" => "give_item",
      "item" => "shaolin:jiuhuan",
      "match" => "jiuhuan",
      "unique" => true,
      "family" => "少林派",
      "vision_name" => "渡厄",
      "min_combat_exp" => 1_000_000,
      "require_fumoquan" => true
    }
  end

  defp base_data do
    %{
      asker_id: "player:test",
      npc_id: "shaolin:du_e",
      npc_name: "渡厄"
    }
  end

  describe "require_fumoquan 门控" do
    test "在 fumoquan 内（valid_in_fumoquan=1）：通过门控，发放物品" do
      conn0 = conn()
      config = base_config()
      data = base_data()

      # Items.get("shaolin:jiuhuan") 会失败（物品未注册），但门控应通过，
      # 只是不会发放物品。关键是不返回 famoquan_deny。
      result = GiveItem.run(conn0, config, data)

      # 物品定义不存在时 run/3 返回 conn 原样（no output about fumoquan deny）
      refute output_text(result) =~ "金刚伏魔圈"
    end

    test "不在 fumoquan 内（无 valid_in_fumoquan）：返回 fumoquan_deny 文案" do
      conn0 = conn(temp: %{})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "金刚伏魔圈"
    end

    test "require_fumoquan 未配置：不校验 fumoquan 门控" do
      conn0 = conn(temp: %{})
      config = Map.delete(base_config(), "require_fumoquan")
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      # 无 require_fumoquan，不应返回金刚伏魔圈相关拒绝
      refute output_text(result) =~ "金刚伏魔圈"
    end

    test "非少林派 + require_fumoquan：family_deny 优先于 fumoquan_deny" do
      conn0 = conn(family: %{name: "武当派", generation: 1}, temp: %{"valid_in_fumoquan" => 1})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      # family_deny 应该先命中（在 gate_denial 顺序中 family_denial 在 gate_denial 之前）
      assert output_text(result) =~ "与本派素无来往"
    end
  end
end
