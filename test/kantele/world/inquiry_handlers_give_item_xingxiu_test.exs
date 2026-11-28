defmodule Kantele.World.InquiryHandlers.GiveItemXingxiuTest do
  @moduledoc """
  `Kantele.World.InquiryHandlers.GiveItem` 的 #814 星宿派 丁春秋 香料：
  NPC 忙/战斗门控、玩家 cooldown_temp 冷却门控。

  随机发放数量（amount_base + random(amount_random)）走 `Helpers.give_items/3`，
  需 Items 缓存与 Records 落盘，与既有 give_item 单元测试一致不在此直接覆盖；
  逻辑通过 `give_amount/1` 的分支与 UCL `amount_base`/`amount_random` 保证。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp conn(opts \\ []) do
    temp = Keyword.get(opts, :temp, %{})

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{combat_exp: 2000000, shen: 0, skills: %{"poison" => 50}},
      family: %{name: "星宿派"},
      temp: temp
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xingxiu:chadian",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
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
      "item" => "clone_lib:xiangliao",
      "match" => "xiangliao",
      "unique" => false,
      "family" => "星宿派",
      "family_deny" => "与我星宿派素无渊源，不知此话从何说起。",
      "npc_busy_deny" => "等会儿，没看我这正忙着呢么？",
      "cooldown_temp" => "get_xiangliao",
      "cooldown_seconds" => 180,
      "cooldown_deny" => "刚才不是给了你吗？不会这么快就用完了吧？",
      "amount_base" => 100,
      "amount_random" => 50,
      "npc_start_busy" => 2,
      "min_skill_levels" => %{"poison" => 40},
      "min_skill_deny" => "你的毒技火候太差，还是练练再说吧！",
      "success" => "好吧，这些香料你拿去慢慢用吧。",
      "exhausted" => "你来晚了，现在没什么剩下的香料了，你还是去仓库找找看吧！"
    }
  end

  defp base_data do
    %{
      asker_id: "player:test",
      npc_id: "xingxiu:ding_chunqiu",
      npc_name: "丁春秋",
      npc_pid: self()
    }
  end

  describe "NPC 忙/战斗门控（#814：家族后、技能门前）" do
    test "npc_busy 为 true：返回 npc_busy_deny 文案，不进入后续门控" do
      conn0 = conn()
      config = base_config()
      data = Map.put(base_data(), :npc_busy, true)

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "正忙着"
    end

    test "npc_fighting 为 true：返回 npc_busy_deny 文案" do
      conn0 = conn()
      config = base_config()
      data = Map.put(base_data(), :npc_fighting, true)

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "正忙着"
    end

    test "NPC 未忙亦未战斗：不触发 busy 门控，继续后续门控" do
      conn0 = conn()
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "正忙着"
    end
  end

  describe "玩家 cooldown_temp 冷却门控（#814：技能门后、库存前）" do
    test "temp[get_xiangliao] 在 180 秒窗口内：返回 cooldown_deny 文案" do
      last = System.system_time(:second) - 60
      conn0 = conn(temp: %{"get_xiangliao" => last})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "用完了吧"
    end

    test "temp[get_xiangliao] 超过 180 秒：不触发冷却门控" do
      last = System.system_time(:second) - 200
      conn0 = conn(temp: %{"get_xiangliao" => last})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "用完了吧"
    end

    test "未设置 temp[get_xiangliao]：不触发冷却门控" do
      conn0 = conn(temp: %{})
      config = base_config()
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "用完了吧"
    end
  end
end
