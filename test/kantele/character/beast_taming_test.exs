defmodule Kantele.Character.BeastTamingTest do
  @moduledoc """
  `BeastState` / `BeastTaming` 共享 helper 的单测。

  重点覆盖 LPC 语义到 Ex 的映射里最容易出错的几处：`race` 双层判定、
  `present()` 的 id/短 id/名字/别名匹配、jing cost 的整除与 `<=` 边界、
  `random(0)` 兜底，以及 `update` 返回 nil 时删条。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.BeastFixtures, as: F
  alias Kantele.Character.BeastState
  alias Kantele.Character.BeastTaming, as: Taming

  setup do
    F.setup_beast_state()
    on_exit(fn -> BeastState.reset() end)
    :ok
  end

  describe "BeastState（LPC NPC 侧 temp dbase）" do
    test "未驯服的野兽查不到状态" do
      assert BeastState.get("nobody") == nil
      assert BeastState.all() == %{}
    end

    test "empty/0 是完整的默认态模板" do
      state = BeastState.empty()
      assert state.owner_id == nil
      assert state.leader_id == nil
      assert state.enemies == []
      assert state.busy == 0
      assert state.ridable == false
    end

    test "update/2 会把默认值补齐；返回 nil 时删除整条" do
      BeastState.update("b1", fn nil -> %{owner_id: "p1"} end)
      assert BeastState.get("b1").owner_id == "p1"
      assert BeastState.get("b1").enemies == []

      BeastState.update("b1", fn _state -> nil end)
      assert BeastState.get("b1") == nil
    end

    test "put/2 与 delete/1、all/0、owned_by/1、reset/0" do
      BeastState.put("b1", %{owner_id: "p1"})
      BeastState.put("b2", %{owner_id: "p1", leader_id: "p1"})
      BeastState.put("b3", %{owner_id: "p2"})

      assert map_size(BeastState.all()) == 3
      assert BeastState.owned_by("p1") |> Enum.map(&elem(&1, 0)) |> Enum.sort() == ["b1", "b2"]

      BeastState.delete("b1")
      assert BeastState.get("b1") == nil

      BeastState.reset()
      assert BeastState.all() == %{}
    end

    test "ensure!/0 可重复调用" do
      assert :ok = BeastState.ensure!()
      assert :ok = BeastState.ensure!()
      assert Process.whereis(BeastState) |> is_pid()
    end
  end

  describe "race 判定（UCL 未建模 race 时的登记表回落）" do
    test "显式 race 优先于登记表" do
      assert Taming.beast?(F.beast(attributes: %{"race" => "野兽"}))
      refute Taming.beast?(F.beast(attributes: %{"race" => "人类"}))
      refute Taming.beast?(F.beast(attributes: %{race: "人类"}))
    end

    test "登记表按短 id / 中文名 / 别名命中" do
      assert Taming.beast?(F.beast())
      assert Taming.beast?(F.beast(id: "other:dushe", name: "毒蛇"))
      assert Taming.beast?(F.beast(id: "x:unknown", name: "无名", attributes: %{"aliases" => ["baihu"]}))
    end

    test "普通 NPC 不是野兽" do
      refute Taming.beast?(F.beast(id: "x:dianxiaoer", name: "店小二"))
    end

    test "登记表规模与 LPC 抄录一致" do
      assert length(Taming.beast_keys()) == 52
      assert length(Taming.beast_names()) == 52
      assert Taming.skill_name() == "training"
      assert Taming.min_skill() == 10
    end
  end

  describe "present() 匹配" do
    test "完整 id / 短 id / 名字 / 前缀 / 别名" do
      b = F.beast(attributes: %{"aliases" => ["hb"]})

      assert Taming.matches?(b, "test:huangbiaoma")
      assert Taming.matches?(b, "huangbiaoma")
      assert Taming.matches?(b, "黄骠马")
      assert Taming.matches?(b, "hb")
      assert Taming.matches?(%{b | name: "黄骠马 小马"}, "黄骠马")
      refute Taming.matches?(b, "骆驼")
    end

    test "characters/1 支持 :beast_characters 与 :room 两种注入" do
      b = F.beast()
      assert Taming.characters(%{private: %{beast_characters: [b]}}) == [b]
      assert Taming.characters(%{private: %{room: %{private: %{characters: [b]}}}}) == [b]
      assert Taming.characters(%{private: %{}}) == []
    end

    test "find/2 取第一个匹配" do
      b = F.beast()
      conn = %{private: %{beast_characters: [b]}}
      assert Taming.find(conn, "黄骠马").id == b.id
      assert Taming.find(conn, "骆驼") == nil
    end
  end

  describe "LPC 判定" do
    test "player?/1" do
      assert Taming.player?(F.player())
      refute Taming.player?(F.beast())
      assert Taming.player?(F.beast(attributes: %{"player" => true}))
    end

    test "living?/1" do
      assert Taming.living?(F.beast())
      refute Taming.living?(F.beast(attributes: %{"not_living" => true}))
      refute Taming.living?(F.beast(attributes: %{"ghost" => true}))
    end

    test "fighting?/1 与 busy?/1 读 BeastState" do
      b = F.beast()
      refute Taming.fighting?(b)
      refute Taming.busy?(b)

      F.set_state(b.id, %{enemies: ["x"], busy: 1})
      assert Taming.fighting?(b)
      assert Taming.busy?(b)
    end

    test "combat_exp/1 与 training_level/1、int/1" do
      assert Taming.combat_exp(F.beast(combat_exp: 5000)) == 5000
      assert Taming.training_level(F.player(training: 33)) == 33
      assert Taming.int(F.player(int: 7)) == 7
    end

    test "jing_cost = max_jing/(training/10)-10；tired? 用 <=" do
      p = F.player(training: 20, max_jing: 200, jing: 500)
      assert Taming.jing_cost(p) == 90
      refute Taming.tired?(p)
      assert Taming.tired?(F.player(training: 20, max_jing: 200, jing: 90))
      assert Taming.tired?(F.player(training: 20, max_jing: 200, jing: 1))
      # training < 10 时除数取 1，不除零
      assert Taming.jing_cost(F.player(training: 0, max_jing: 200)) == 190
    end

    test "ridable?/1 按名字里的字判定" do
      assert Taming.ridable?("黄骠马")
      assert Taming.ridable?("白虎")
      assert Taming.ridable?("骆驼")
      refute Taming.ridable?("毒蛇")
      assert length(Taming.ridable_markers()) == 13
    end
  end

  describe "roll_failure?/3" do
    test "注入固定成败" do
      conn = %{private: %{beast_roll: fn sp, dp -> {sp, dp} end}}
      assert Taming.roll_failure?(conn, F.player(training: 20, int: 20), F.beast(combat_exp: 1000)) ==
               {40, 10}
    end

    test "sp = 0 / dp = 0 时按 LPC random(0)=0 兜底，不抛异常" do
      conn = %{private: %{}}
      p = F.player(training: 0, int: 0)
      npc = F.beast(combat_exp: 0)
      assert Taming.roll_failure?(conn, p, npc) == false
    end
  end

  describe "owner 归一（不复刻 LPC 对象/字符串混用 bug）" do
    test "owner/owned_by?/foreign_owner?/no_owner?" do
      b = F.beast()
      me = F.player()

      assert Taming.no_owner?(b)
      refute Taming.owned_by?(b, me)
      refute Taming.foreign_owner?(b, me)

      F.set_state(b.id, %{owner_id: "player-1"})
      assert Taming.owner(b) == "player-1"
      assert Taming.owned_by?(b, me)
      refute Taming.foreign_owner?(b, me)

      F.set_state(b.id, %{owner_id: "player-2"})
      assert Taming.foreign_owner?(b, me)
    end
  end
end
