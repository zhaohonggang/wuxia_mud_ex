defmodule Kantele.NPC.ZhangSanfengTest do
  @moduledoc """
  张三丰 NPC 问询处理器定向测试。

  覆盖：「鹤嘴劲」check 的 LPC 真实门控（武当派 / 太极神功≥100 / 功绩≥800 /
  神≥150000 / 内力≥1500）。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.NPC.ZhangSanfeng

  defp character(opts \\ []) do
    stats =
      Stats.new()
      |> Map.put(:skills, Keyword.get(opts, :skills, %{"taiji-shengong" => 120}))
      |> Map.put(:gongxian, Keyword.get(opts, :gongxian, 1000))
      |> Map.put(:shen, Keyword.get(opts, :shen, 200_000))

    vitals =
      %Vitals{
        max_neili: Keyword.get(opts, :max_neili, 2000),
        neili: Keyword.get(opts, :neili, 2000)
      }

    family =
      Keyword.get(opts, :family, %{name: "武当派", master_id: "zhang_sanfeng", master_name: "张三丰"})

    %Character{
      id: "zsf-test-player",
      name: "张测试",
      pid: self(),
      room_id: "wudang:zhenwudian",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        family: family
      }
    }
  end

  defp npc(), do: %{id: "zhang_sanfeng", name: "张三丰", pid: self(), room_id: "wudang:zhenwudian"}

  describe "ZhangSanfeng.ask_specs/0 「鹤嘴劲」check 门控" do
    test "非武当派 → 拒绝" do
      c = character(family: %{name: "少林派", master_id: "du", master_name: "渡难"})
      assert {:error, msg} = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
      assert msg =~ "不是我们武当派的人"
    end

    test "无门派记录 → 拒绝" do
      c = character(family: nil)
      assert {:error, msg} = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
      assert msg =~ "不是我们武当派的人"
    end

    test "武当派但太极神功 < 100 → 拒绝" do
      c = character(skills: %{"taiji-shengong" => 99})
      assert {:error, msg} = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
      assert msg =~ "太极神功都没学"
    end

    test "武当派但功绩 < 800 → 拒绝" do
      c = character(gongxian: 799)
      assert {:error, msg} = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
      assert msg =~ "效力还不够"
    end

    test "武当派但神 < 150000 → 拒绝" do
      c = character(shen: 149_999)
      assert {:error, msg} = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
      assert msg =~ "做的还很不够"
    end

    test "武当派但内力上限 < 1500 → 拒绝" do
      c = character(max_neili: 1499)
      assert {:error, msg} = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
      assert msg =~ "内力修为太浅"
    end

    test "全门票达标 → :ok 放行" do
      c = character()
      assert :ok = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
    end

    test "边界值：taiji-shengong = 100 → 放行" do
      c = character(skills: %{"taiji-shengong" => 100})
      assert :ok = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
    end

    test "边界值：gongxian = 800 → 放行" do
      c = character(gongxian: 800)
      assert :ok = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
    end

    test "边界值：shen = 150000 → 放行" do
      c = character(shen: 150_000)
      assert :ok = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
    end

    test "边界值：max_neili = 1500 → 放行" do
      c = character(max_neili: 1500)
      assert :ok = ZhangSanfeng.check(c, npc(), "鹤嘴劲")
    end
  end
end
