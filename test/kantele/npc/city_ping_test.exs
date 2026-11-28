defmodule Kantele.NPC.CityPingTest do
  @moduledoc """
  平一指 NPC 问询处理器定向测试（对应 LPC `d/city/npc/ping.c` 的 `ask_job()`）。

  覆盖：
    - ask_specs 关键字与 UCL inquiries 对齐（配药 / 工作 / job）
    - check/3 四道守门（已领活 / 太屈就 / 太弱 / 气不足）+ 放行
    - execute/3 设 `temp job/peiyao=1` 并返回领活提示
    - clone_lib.ucl 接线（ask_handler + inquiries）

  结算逻辑（经验、潜能、铜钱、mark）由 `Kantele.World.NpcActions.PeiyaoTest` 覆盖，
  本测试不重复。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.NPC.CityPing

  defp asker(opts \\ []) do
    %Character{
      id: Keyword.get(opts, :id, "player-ping"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "kaifeng:yaopu",
      meta: %PlayerMeta{
        stats: Keyword.get(opts, :stats, %Stats{combat_exp: 10_000}),
        vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100, max_qi: 100}),
        temp: Keyword.get(opts, :temp, %{}),
        marks: Keyword.get(opts, :marks, %{})
      }
    }
  end

  defp npc(), do: %{id: "city_ping", name: "平一指", pid: self(), room_id: "kaifeng:yaopu"}

  describe "CityPing.ask_specs/0 关键字覆盖（对齐 UCL inquiries）" do
    test "包含配药 / 工作 / job 三个关键字，且每个 spec 三回调齐全" do
      specs = CityPing.ask_specs()

      for keyword <- ["配药", "工作", "job"] do
        assert spec = specs[keyword]
        assert is_function(spec.check, 2)
        assert is_function(spec.execute, 2)
        assert is_list(spec.effects)
      end
    end

    test "未知关键字 check / execute 均拒绝" do
      assert {:error, _} = CityPing.check(asker(), npc(), "随便")
      assert {:error, _} = CityPing.execute(asker(), npc(), "随便")
    end
  end

  describe "CityPing.check/3 守门（严格对齐 LPC ask_job 顺序）" do
    test "已领活未完成 → 拒绝「让你干的活你干完了么？」" do
      a = asker(temp: %{"job/peiyao" => 1})
      assert {:error, msg} = CityPing.check(a, npc(), "配药")
      assert msg =~ "干完了么"
    end

    test "combat_exp>20000 且 mark/job_peiyao>1000 → 拒绝「太屈就」" do
      a = asker(stats: %Stats{combat_exp: 50_000}, marks: %{"job/peiyao" => 1001})
      assert {:error, msg} = CityPing.check(a, npc(), "配药")
      assert msg =~ "太屈就"
    end

    test "combat_exp=20000 / mark=1000 恰在阈值边界 → 不触发「太屈就」" do
      a = asker(stats: %Stats{combat_exp: 20_000}, marks: %{"job/peiyao" => 1000})
      assert :ok = CityPing.check(a, npc(), "配药")
    end

    test "combat_exp<5000 → 拒绝「端不起来」" do
      a = asker(stats: %Stats{combat_exp: 4_999})
      assert {:error, msg} = CityPing.check(a, npc(), "配药")
      assert msg =~ "端不起来"
    end

    test "qi<5 → 拒绝「先歇歇」" do
      a = asker(vitals: %Vitals{qi: 4, max_qi: 100})
      assert {:error, msg} = CityPing.check(a, npc(), "配药")
      assert msg =~ "先歇歇"
    end

    test "三个关键字均可放行（正常角色）" do
      for keyword <- ["配药", "工作", "job"] do
        assert :ok = CityPing.check(asker(), npc(), keyword)
      end
    end

    test "门序：已领活优先于太弱（同时命中时返回「干完了么」）" do
      a = asker(temp: %{"job/peiyao" => 1}, stats: %Stats{combat_exp: 100})
      assert {:error, msg} = CityPing.check(a, npc(), "配药")
      assert msg =~ "干完了么"
    end
  end

  describe "CityPing.execute/3 领活（对应 LPC set_temp job/peiyao）" do
    test "放行后设 temp job/peiyao=1 并返回领活提示 + 更新后的角色" do
      a = asker()
      assert {:ok, msg, updated} = CityPing.execute(a, npc(), "配药")
      assert msg =~ "帮我配药(peiyao)吧"
      assert msg =~ "喏，就这几味"
      assert updated.meta.temp["job/peiyao"] == 1
      # 领活阶段不结算经验/潜能/mark
      assert updated.meta.stats.combat_exp == 10_000
      assert updated.meta.marks == %{}
    end

    test "execute 守门与 check 一致（已领活 / 太弱 / 气不足）" do
      pending = asker(temp: %{"job/peiyao" => 1})
      assert {:error, msg} = CityPing.execute(pending, npc(), "配药")
      assert msg =~ "干完了么"

      weak = asker(stats: %Stats{combat_exp: 100})
      assert {:error, msg} = CityPing.execute(weak, npc(), "配药")
      assert msg =~ "端不起来"

      low_qi = asker(vitals: %Vitals{qi: 1, max_qi: 100})
      assert {:error, msg} = CityPing.execute(low_qi, npc(), "配药")
      assert msg =~ "先歇歇"
    end

    test "effects/3 为空（结算在 peiyao 动词侧）" do
      assert CityPing.effects(asker(), npc(), "配药") == []
    end
  end

  describe "UCL 接线" do
    test "clone_lib.ucl city_ping 块配置了 ask_handler" do
      ucl = File.read!("data/world/clone_lib.ucl")
      assert ucl =~ ~s(ask_handler = "Kantele.NPC.CityPing")
    end

    test "clone_lib.ucl city_ping inquiries 关键字与 ask_specs 一致" do
      ucl = File.read!("data/world/clone_lib.ucl")

      for keyword <- ["配药", "工作", "job"] do
        assert ucl =~ ~s({ key = "#{keyword}" value =)
      end
    end
  end
end
