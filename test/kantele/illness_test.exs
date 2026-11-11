defmodule Kantele.IllnessTest do
  use ExUnit.Case, async: true

  alias Kantele.Illness

  # 纯函数宿主状态：仅 attributes.qi + condition_messages（do_effect 只读/写这两键）
  defp state(qi), do: %{attributes: %{qi: qi}, condition_messages: []}

  describe "daemon/1 —— 五个疾病 cnd 指向本模块，其余拒绝" do
    test "五族均解析为 {:ok, __MODULE__}" do
      for cnd <- ~w(ill_kesou ill_zhongshu ill_shanghan ill_dongshang ill_fashao) do
        assert {:ok, Kantele.Illness} = Illness.daemon(cnd)
      end
    end

    test "非疾病 cnd 返回 :error" do
      assert :error = Illness.daemon("poison")
      assert :error = Illness.daemon("drunk")
      assert :error = Illness.daemon("ill_unknown")
      assert :error = Illness.daemon(nil)
    end
  end

  describe "update_condition/1 —— duration 倒计时，<1 到期" do
    test "duration 减 1 并保留其余字段" do
      info = %{"duration" => 5, "announce" => "test"}
      assert {:continue, %{"duration" => 4, "announce" => "test"}} =
               Illness.update_condition(info)
    end

    test "duration 为 1 时下一跳到期（:expire）" do
      assert {:expire} = Illness.update_condition(%{"duration" => 1})
    end

    test "duration 已 <1 直接 :expire" do
      assert {:expire} = Illness.update_condition(%{"duration" => 0})
      assert {:expire} = Illness.update_condition(%{})
      assert {:expire} = Illness.update_condition(nil)
    end
  end

  describe "do_effect/3 —— 每跳扣 qi（2×family.qi）并推送文案" do
    test "kesou：qi 减 4，推送 tell + vision" do
      {:ok, state} = Illness.do_effect(state(1000), "ill_kesou", nil)

      assert state.attributes.qi == 996
      assert state.condition_messages == [
               {:tell, "你嘶哑着嗓子咳了两声，然后又连续咳了好一阵，看来是病的不轻！\n"},
               {:vision, "{npc}嘶哑着嗓子咳了两声，然后\n又连续咳了好一阵，看来是病的不轻！\n"}
             ]
    end

    test "shanghan：qi 减 12（家族最高伤害）" do
      {:ok, state} = Illness.do_effect(state(1000), "ill_shanghan", nil)
      assert state.attributes.qi == 988
    end

    test "zhongshu：qi 减 8" do
      {:ok, state} = Illness.do_effect(state(1000), "ill_zhongshu", nil)
      assert state.attributes.qi == 992
    end

    test "dongshang / fashao：qi 减 4" do
      {:ok, s1} = Illness.do_effect(state(1000), "ill_dongshang", nil)
      {:ok, s2} = Illness.do_effect(state(1000), "ill_fashao", nil)
      assert s1.attributes.qi == 996
      assert s2.attributes.qi == 996
    end

    test "qi 不击穿下限（夹 0）" do
      {:ok, state} = Illness.do_effect(state(3), "ill_shanghan", nil)
      assert state.attributes.qi == 0
    end

    test "未知 cnd 原样返回，不推文案" do
      {:ok, state} = Illness.do_effect(state(1000), "ill_unknown", nil)
      assert state.attributes.qi == 1000
      assert state.condition_messages == []
    end
  end

  describe "min_qi_needed/1 —— 家族最严阈值（伤寒 20）" do
    test "任意属性返回 20" do
      assert 20 = Illness.min_qi_needed(%{qi: 1})
      assert 20 = Illness.min_qi_needed(%{qi: 999})
      assert 20 = Illness.min_qi_needed(%{})
    end
  end

  describe "dispel_condition/2 —— 驱火候/内力门控" do
    test "force 不足：{:fail, \"内功火候...\"" do
      info = %{"duration" => 10}
      ctx = %{force: 60, neili: 999, self?: true}  # need_lvl = 10+60 = 70 > 60

      assert {:fail, msg} = Illness.dispel_condition(info, ctx)
      assert msg =~ "内功火候"
    end

    test "neili 不足：{:fail, \"内力...\"" do
      info = %{"duration" => 10}
      ctx = %{force: 999, neili: 50, self?: true}  # need_neili = 10*10 = 100 > 50

      assert {:fail, msg} = Illness.dispel_condition(info, ctx)
      assert msg =~ "内力"
    end

    test "他人驱散：门槛 ×3/2" do
      info = %{"duration" => 10}
      # 自身：need_lvl=70, need_neili=100；他人：need_lvl=105, need_neili=150
      refute match?({:ok, _}, Illness.dispel_condition(info, %{force: 100, neili: 120, self?: false}))
      assert {:ok, _} = Illness.dispel_condition(info, %{force: 200, neili: 300, self?: false})
    end

    test "达标：{:ok, msg} 且文案含调息/经脉" do
      info = %{"duration" => 10}
      ctx = %{force: 200, neili: 300, self?: true}

      assert {:ok, msg} = Illness.dispel_condition(info, ctx)
      assert msg =~ "调息" or msg =~ "舒服"
    end

    test "非 map info 返回 :skip" do
      assert :skip = Illness.dispel_condition(nil, %{})
    end
  end

  describe "family/0 —— 五族数据齐全" do
    test "每族都有 qi / min_qi / self / others" do
      for {_cnd, data} <- Illness.family() do
        assert is_integer(data.qi) and data.qi > 0
        assert is_integer(data.min_qi) and data.min_qi > 0
        assert is_binary(data.self)
        assert is_binary(data.others)
      end
    end
  end
end
