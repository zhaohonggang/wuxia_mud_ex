defmodule Kantele.World.InquiryHandlers.GiveItemShaolinTest do
  @moduledoc """
  `Kantele.World.InquiryHandlers.GiveItem` 的 #1045 少林门控：
  道象 bonze_drug 条件 / 清乐 guilty 戒律 / min_int 资质 / generation_skill 辈分动态门槛。

  测试 `run/3` 通过 `gate_denial/3` 校验新增配置键。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "少林派", generation: 35})
    guilty = Keyword.get(opts, :guilty, 0)
    temp = Keyword.get(opts, :temp, %{})
    conditions = Keyword.get(opts, :conditions, %{})

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{combat_exp: 2000000, shen: 0, skills: %{}},
      family: family,
      guilty: guilty,
      temp: temp
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:qingjing",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{"conditions" => conditions}
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
      "item" => "shaolin:jinchuang_yao",
      "match" => "jinchuang_yao",
      "unique" => true,
      "family" => "少林派",
      "vision_name" => "道象",
      "count" => "jin_count"
    }
  end

  defp base_data do
    %{
      asker_id: "player:test",
      npc_id: "shaolin:dao_xiang2",
      npc_name: "道象"
    }
  end

  describe "bonze_drug 门控（道象 金创药）" do
    test "条件 bonze_drug > 0：返回 bonze_drug_deny 文案" do
      conn0 = conn(conditions: %{"bonze_drug" => 5})
      config = Map.put(base_config(), "bonze_drug", true)
      config = Map.put(config, "bonze_drug_deny", "你刚服过金创药，药力尚未耗尽，暂时不必再服。")
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "你刚服过金创药"
    end

    test "条件 bonze_drug = 0：不拒绝，继续门控" do
      conn0 = conn(conditions: %{"bonze_drug" => 0})
      config = Map.put(base_config(), "bonze_drug", true)
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      # bonze_drug=0 不拒，物品未注册不发放，也不应返回 bonze_drug_deny
      refute output_text(result) =~ "药力尚未耗尽"
    end

    test "未配置 bonze_drug：不校验条件门控" do
      conn0 = conn(conditions: %{"bonze_drug" => 5})
      config = base_config() # 无 bonze_drug 键
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "药力尚未耗尽"
    end
  end

  describe "guilty 门控（清乐 手谕）" do
    test "meta.guilty > 0：返回 guilty_deny 文案" do
      conn0 = conn(guilty: 2)
      config = Map.put(base_config(), "item", "shaolin:allow_letter")
      config = Map.put(config, "guilty_deny", "你累犯数戒，身带重罪，我如何能给你这手谕！")
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "累犯数戒"
    end

    test "meta.guilty = 0：不拒绝，继续门控" do
      conn0 = conn(guilty: 0)
      config = Map.put(base_config(), "item", "shaolin:allow_letter")
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "累犯数戒"
    end
  end

  describe "min_int 门控（清乐 手谕）" do
    test "Stats.int < min_int：返回 min_int_deny 文案" do
      conn0 = conn()
      config = Map.put(base_config(), "item", "shaolin:allow_letter")
      config = Map.put(config, "min_int", 30)
      config = Map.put(config, "min_int_deny", "资质不够，不能进入藏经楼。")
      # 覆盖 stats，使 int < 30
      character = %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:qingjing",
        meta: %PlayerMeta{
          vitals: %Vitals{qi: 100},
          stats: %Stats{combat_exp: 2000000, shen: 0, int: 10, skills: %{}},
          family: %{name: "少林派", generation: 35},
          guilty: 0,
          temp: %{}
        }
      }
      conn0 = %{
        conn0 | character: character, private: %Conn.Private{channel_changes: []}, output: [], session: %{}
      }
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "资质不够"
    end

    test "Stats.int >= min_int：不拒绝，继续门控" do
      conn0 = conn()
      character = %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:qingjing",
        meta: %PlayerMeta{
          vitals: %Vitals{qi: 100},
          stats: %Stats{combat_exp: 2000000, shen: 0, int: 35, skills: %{}},
          family: %{name: "少林派", generation: 35},
          guilty: 0,
          temp: %{}
        }
      }
      conn0 = %{
        conn0 | character: character, private: %Conn.Private{channel_changes: []}, output: [], session: %{}
      }
      config = Map.put(base_config(), "item", "shaolin:allow_letter")
      config = Map.put(config, "min_int", 30)
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "资质不够"
    end
  end

  describe "generation_skill 门控（清乐 达摩令）" do
    test "辈分动态阈值未达标：返回 generation_skill_deny 文案" do
      # generation=35 → threshold=(41-35)*20+30 = 150
      # skill level 100 < 150 → 拒
      conn0 = conn(family: %{name: "少林派", generation: 35})
      config = Map.put(base_config(), "item", "shaolin:damo_ling")
      config = Map.put(config, "generation_skill_levels", %{"buddhism" => 0, "dodge" => 0, "shaolin_shenfa" => 0, "force" => 0, "parry" => 0})
      config = Map.put(config, "generation_skill_deny", "你{skill}的功力不够，不能领取达摩令。")
      # 覆盖 stats，使 skills 全为 0
      character = %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:qingjing",
        meta: %PlayerMeta{
          vitals: %Vitals{qi: 100},
          stats: %Stats{combat_exp: 2000000, shen: 0, int: 35, skills: %{"buddhism" => 100, "dodge" => 100, "shaolin_shenfa" => 100, "force" => 100, "parry" => 100}},
          family: %{name: "少林派", generation: 35},
          guilty: 0,
          temp: %{}
        }
      }
      conn0 = %{
        conn0 | character: character, private: %Conn.Private{channel_changes: []}, output: [], session: %{}
      }
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      assert output_text(result) =~ "功力不够"
      assert output_text(result) =~ "达摩令"
    end

    test "辈分动态阈值已达标：不拒绝，继续门控" do
      # generation=35 → threshold=150
      # skill level 200 >= 150 → 通过
      conn0 = conn(family: %{name: "少林派", generation: 35})
      config = Map.put(base_config(), "item", "shaolin:damo_ling")
      config = Map.put(config, "generation_skill_levels", %{"buddhism" => 0, "dodge" => 0, "shaolin_shenfa" => 0, "force" => 0, "parry" => 0})
      character = %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "shaolin:qingjing",
        meta: %PlayerMeta{
          vitals: %Vitals{qi: 100},
          stats: %Stats{combat_exp: 2000000, shen: 0, int: 35, skills: %{"buddhism" => 200, "dodge" => 200, "shaolin_shenfa" => 200, "force" => 200, "parry" => 200}},
          family: %{name: "少林派", generation: 35},
          guilty: 0,
          temp: %{}
        }
      }
      conn0 = %{
        conn0 | character: character, private: %Conn.Private{channel_changes: []}, output: [], session: %{}
      }
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "功力不够"
    end

    test "未配置 generation_skill_levels：不校验辈分门控" do
      conn0 = conn(family: %{name: "少林派", generation: 1})
      config = base_config() # 无 generation_skill_levels
      data = base_data()

      result = GiveItem.run(conn0, config, data)

      refute output_text(result) =~ "功力不够"
    end
  end
end
