defmodule Kantele.World.LoaderInquiryStateTest do
  use ExUnit.Case, async: true

  test "parse_character 归一 inquiry_state 键并保留脚本 map" do
    data = %{
      name: "武修文",
      description: "",
      combat: %{},
      inquiry_state: %{huju_count: 20, beixin_count: 2},
      inquiries: %{
        铁护腕: %{kind: "give_item", item: "shaolin:huwan", count: "huju_count"}
      }
    }

    {_, npc} = Kantele.World.Loader.parse_character(%{id: "xiangyang"}, "wuxiuwen", data, %{})

    assert npc.meta.inquiry_state == %{"huju_count" => 20, "beixin_count" => 2}
    assert npc.meta.inquiries["铁护腕"]["kind"] == "give_item"
  end

  test "缺省 inquiry_state 为 %{}" do
    data = %{name: "路人", description: "", combat: %{}}

    {_, npc} = Kantele.World.Loader.parse_character(%{id: "test"}, "passerby", data, %{})

    assert npc.meta.inquiry_state == %{}
  end

  test "max_skill_levels 键归一（下划线→连字符，与 Stats.skills 一致）" do
    data = %{
      name: "齐云敖",
      description: "",
      combat: %{},
      inquiries: %{
        毒经中篇: %{
          kind: "give_item",
          item: "wudu:dujing2",
          max_skill_levels: %{poison: 119, wu_du_qishu: 200}
        }
      }
    }

    {_, npc} = Kantele.World.Loader.parse_character(%{id: "wudu"}, "qiyunao", data, %{})

    assert npc.meta.inquiries["毒经中篇"]["max_skill_levels"] == %{
             "poison" => 119,
             "wu-du-qishu" => 200
           }
  end

  test "counter_perform 的 min_levels / level_deny 键归一（对齐 Stats.skills）" do
    data = %{
      name: "张三丰",
      description: "",
      combat: %{},
      inquiries: %{
        太极图: %{
          kind: "counter_perform",
          perform_id: "taiji-quan/tu",
          counter_key: "can_perform/taiji-quan/tu",
          max_count: 10,
          min_levels: %{taiji_quan: 250, taiji_shengong: 300, taoism: 300},
          level_deny: %{
            taiji_quan: "你的太极拳法还不到家，要多练练！",
            taiji_shengong: "你的太极神功还不到家，好好修行吧！",
            taoism: "你的道学心法研究的还不够明白，要下功夫苦学才是！"
          }
        }
      }
    }

    {_, npc} = Kantele.World.Loader.parse_character(%{id: "wudang"}, "wudang_zhang", data, %{})

    inquiry = npc.meta.inquiries["太极图"]
    assert inquiry["min_levels"] == %{"taiji-quan" => 250, "taiji-shengong" => 300, "taoism" => 300}

    assert inquiry["level_deny"] == %{
             "taiji-quan" => "你的太极拳法还不到家，要多练练！",
             "taiji-shengong" => "你的太极神功还不到家，好好修行吧！",
             "taoism" => "你的道学心法研究的还不够明白，要下功夫苦学才是！"
           }

    # 数字字段原样保留（int/2 容错在 handler 侧）
    assert inquiry["max_count"] == 10
  end
end
