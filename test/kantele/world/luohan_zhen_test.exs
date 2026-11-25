defmodule Kantele.World.LuohanZhenTest do
  @moduledoc """
  #1064：十八罗汉大阵纯状态机测试（LuohanZhen）。

  测试覆盖：
  - initiate/2 全五门控（非少林长老 / 技能不足 / 已闯过 / 辈份不合 / 有罪 / 成功）
  - merge/2 双长老合并
  - waiting/1 超时 / 另一长老未问 / 双方齐备
  - preparing/1 副作用效果
  - fighting/2 各轮移僧、胜负判定
  - do_recruit/1 同门 vs 异门文案与延迟
  - do_back/1 终结重置
  """

use ExUnit.Case, async: true

alias Kantele.World.LuohanZhen

import Enum

  @xuanku "shaolin_xuan_ku"
  @xuannan "shaolin_xuan_nan"

  # --- 测试用 NPC（长老） ---

  defp xuan_ku(overrides \\ %{}) do
    %{
      id: @xuanku,
      name: "玄苦",
      room_id: "shaolin:wuchang",
      meta: %{
        family: %{name: "少林派", generation: 35}
      } |> Map.merge(Map.new(overrides))
    }
  end

  defp xuan_nan(overrides \\ %{}) do
    %{
      id: @xuannan,
      name: "玄难",
      room_id: "shaolin:wuchang",
      meta: %{
        family: %{name: "少林派", generation: 35}
      } |> Map.merge(Map.new(overrides))
    }
  end

  defp non_shaolin_master(overrides \\ %{}) do
    %{
      id: "wudang_zhang",
      name: "张三丰",
      room_id: "wudang:tiyun",
      meta: %{
        family: %{name: "武当派", generation: 30}
      } |> Map.merge(Map.new(overrides))
    }
  end

  # --- 测试用玩家 ---

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

  defp shaolin_fighter(gen \\ 35, overrides \\ %{}) do
    %{
      id: "player:test",
      name: "测试玩家",
      room_id: "shaolin:wuchang",
      meta: %{
        family: %{name: "少林派", generation: gen},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{},
        temp: %{}
      }
    } |> Map.merge(Map.new(overrides))
  end

  defp non_shaolin_fighter(overrides \\ %{}) do
    %{
      id: "player:test",
      name: "测试玩家",
      room_id: "shaolin:wuchang",
      meta: %{
        family: %{name: "武当派", generation: 30},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{},
        temp: %{}
      }
    } |> Map.merge(Map.new(overrides))
  end

  describe "initiate/2 门控" do
    test "非少林派长老 → :not_shaolin_master" do
      f = fighter()
      m = non_shaolin_master()

      assert LuohanZhen.initiate(f, m) == {:error, :not_shaolin_master}
    end

    test "技能不足（只有一技且<80）→ :skills_insufficient" do
      f = shaolin_fighter(35, meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"force" => 50}},
        env: %{}, temp: %{}
      })
      m = xuan_ku()

      assert LuohanZhen.initiate(f, m) == {:error, :skills_insufficient}
    end

    test "技能不足（多技但均<80）→ :skills_insufficient" do
      f = shaolin_fighter(35, meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"strike" => 70, "unarmed" => 75}},
        env: %{}, temp: %{}
      })
      m = xuan_ku()

      assert LuohanZhen.initiate(f, m) == {:error, :skills_insufficient}
    end

    test "任一检查技能>=80 → 技能门控通过" do
      f = shaolin_fighter(35, meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"strike" => 80, "unarmed" => 70}},
        env: %{}, temp: %{}
      })
      m = xuan_ku()

      assert match?({:ok, %LuohanZhen{}, _}, LuohanZhen.initiate(f, m))
    end

    test "已闯过阵（luohan_winner=1）→ :already_winner" do
      f = shaolin_fighter(35, meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{"luohan_winner" => 1},
        temp: %{}
      })
      m = xuan_ku()

      assert LuohanZhen.initiate(f, m) == {:error, :already_winner}
    end

    test "已闯过阵（luohan_winner=true）→ :already_winner" do
      f = shaolin_fighter(35, meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{"luohan_winner" => true},
        temp: %{}
      })
      m = xuan_ku()

      assert LuohanZhen.initiate(f, m) == {:error, :already_winner}
    end

    test "辈份高于长老+2 → :generation_mismatch" do
      f = shaolin_fighter(38, meta: %{
        family: %{name: "少林派", generation: 38},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{}, temp: %{}
      })
      m = xuan_ku() # generation 35, 38 > 35+2

      assert LuohanZhen.initiate(f, m) == {:error, :generation_mismatch}
    end

    test "辈份等于长老+2 → 通过" do
      f = shaolin_fighter(37, meta: %{
        family: %{name: "少林派", generation: 37},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{}, temp: %{}
      })
      m = xuan_ku() # generation 35, 37 <= 35+2

      assert match?({:ok, %LuohanZhen{}, _}, LuohanZhen.initiate(f, m))
    end

    test "非少林派玩家不受辈份限制" do
      f = non_shaolin_fighter(meta: %{
        family: %{name: "武当派", generation: 50},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{}, temp: %{}
      })
      m = xuan_ku() # generation 35, 50 > 35+2 but non-shaolin

      assert match?({:ok, %LuohanZhen{}, _}, LuohanZhen.initiate(f, m))
    end

    test "guilty>0 → :guilty" do
      f = shaolin_fighter(35, meta: %{
        family: %{name: "少林派", generation: 35},
        stats: %{skills: %{"strike" => 100, "unarmed" => 90}},
        env: %{"guilty" => 2},
        temp: %{}
      })
      m = xuan_ku()

      assert LuohanZhen.initiate(f, m) == {:error, :guilty}
    end

    test "全部门控通过 → {:ok, challenge, effects}" do
      f = fighter()
      m = xuan_ku()

      {:ok, challenge, effects} = LuohanZhen.initiate(f, m)

      assert challenge.state == :summoning
      assert challenge.fighter_id == "player:test"
      assert challenge.fighter_name == "测试玩家"
      assert challenge.master_asked == %{"xuanku" => true, "xuannan" => false}
      assert challenge.assigned_by == "xuanku"
      assert challenge.temp_flags == %{}  # temp_flags set via effects
      assert any?(effects, fn {:put_temp, "player:test", "xuanku-asked", 1} -> true; _ -> false end)
      assert is_list(effects)
    end

    test "ask 玄难 → assigned_by=xuannan, temp_flag=xuannan-asked" do
      f = fighter()
      m = xuan_nan()

      {:ok, challenge, effects} = LuohanZhen.initiate(f, m)

      assert challenge.master_asked == %{"xuanku" => false, "xuannan" => true}
      assert challenge.assigned_by == "xuannan"
      assert challenge.temp_flags == %{}  # temp_flags is set via effects, not in struct
      assert any?(effects, fn {:put_temp, "player:test", "xuannan-asked", 1} -> true; _ -> false end)
    end

    test "无效参数 → {:error, :invalid_args}" do
      assert LuohanZhen.initiate(nil, nil) == {:error, :invalid_args}
      assert LuohanZhen.initiate(%{}, %{}) == {:error, :invalid_args}
    end
  end

  describe "merge/2 双长老合并" do
    test "先问玄苦再问玄难，合并 master_asked 和 temp_flags" do
      challenge =
        %LuohanZhen{
          fighter_id: "player:test",
          fighter_name: "测试玩家",
          fighter_room_id: "shaolin:wuchang",
          state: :summoning,
          master_asked: %{"xuanku" => true, "xuannan" => false},
          temp_flags: %{"xuanku-asked" => 1},
          wait_time: 0,
          beat_count: 0,
          round: 0,
          timer_refs: %{},
          result: nil,
          assigned_by: "xuanku"
        }

      merged = LuohanZhen.merge(challenge, "xuannan")

      assert merged.master_asked == %{"xuanku" => true, "xuannan" => true}
      assert merged.temp_flags == %{"xuanku-asked" => 1, "xuannan-asked" => 1}
    end

    test "先问玄难再问玄苦，合并 master_asked 和 temp_flags" do
      challenge =
        %LuohanZhen{
          fighter_id: "player:test",
          fighter_name: "测试玩家",
          fighter_room_id: "shaolin:wuchang",
          state: :summoning,
          master_asked: %{"xuanku" => false, "xuannan" => true},
          temp_flags: %{"xuannan-asked" => 1},
          wait_time: 0,
          beat_count: 0,
          round: 0,
          timer_refs: %{},
          result: nil,
          assigned_by: "xuannan"
        }

      merged = LuohanZhen.merge(challenge, "xuanku")

      assert merged.master_asked == %{"xuanku" => true, "xuannan" => true}
      assert merged.temp_flags == %{"xuanku-asked" => 1, "xuannan-asked" => 1}
    end

    test "未知 master_side 不修改 temp_flags" do
      challenge =
        %LuohanZhen{
          fighter_id: "player:test",
          master_asked: %{"xuanku" => true, "xuannan" => false},
          temp_flags: %{"xuanku-asked" => 1},
          wait_time: 0,
          beat_count: 0,
          round: 0,
          timer_refs: %{},
          result: nil,
          assigned_by: "xuanku"
        }

      merged = LuohanZhen.merge(challenge, "unknown")

      assert merged.master_asked == %{"xuanku" => true, "xuannan" => false}
      assert merged.temp_flags == %{"xuanku-asked" => 1}
    end
  end

  describe "waiting/1 等待状态" do
    defp waiting_challenge(overrides \\ %{}) do
      %LuohanZhen{
        fighter_id: "player:test",
        fighter_name: "测试玩家",
        fighter_room_id: "shaolin:wuchang",
        state: :waiting,
        master_asked: %{"xuanku" => true, "xuannan" => false},
        temp_flags: %{"xuanku-asked" => 1},
        wait_time: 0,
        beat_count: 0,
        round: 0,
        timer_refs: %{},
        result: nil,
        assigned_by: "xuanku"
      } |> Map.merge(Map.new(overrides))
    end

    test "wait_time>=300 → 超时，result=:timeout" do
      c = waiting_challenge(wait_time: 300)

      {:ok, c2, effects} = LuohanZhen.waiting(c)

      assert c2.state == :finished
      assert c2.result == :timeout
      assert c2.temp_flags == %{}
      # do_back_effects contains broadcast, move_npc, etc. (not {:do_back, :timeout})
      assert any?(effects, fn {:broadcast, "shaolin:wuchang", _} -> true; _ -> false end)
      refute any?(effects, fn {:schedule_timer, _, _} -> true; _ -> false end)
    end

    test "另一长老未被问 → 继续等待，wait_time+1，schedule :waiting" do
      c = waiting_challenge()

      {:ok, c2, effects} = LuohanZhen.waiting(c)

      assert c2.state == :waiting
      assert c2.wait_time == 1
      assert any?(effects, fn {:schedule_timer, :waiting, 1000} -> true; _ -> false end)
    end

    test "另一长老临时标志未设置 → 继续等待" do
      c = waiting_challenge(temp_flags: %{})

      {:ok, c2, effects} = LuohanZhen.waiting(c)

      assert c2.state == :waiting
      assert c2.wait_time == 1
      assert any?(effects, fn {:schedule_timer, :waiting, 1000} -> true; _ -> false end)
    end

    test "双方长老均被问 → 进入 preparing，wait_time=0" do
      c = waiting_challenge(
        master_asked: %{"xuanku" => true, "xuannan" => true},
        temp_flags: %{"xuanku-asked" => 1, "xuannan-asked" => 1}
      )

      {:ok, c2, effects} = LuohanZhen.waiting(c)

      assert c2.state == :preparing
      assert c2.wait_time == 0
      assert any?(effects, fn {:schedule_timer, :fighting, 10_000} -> true; _ -> false end)
    end
  end

  describe "preparing/1 备战状态" do
    defp preparing_challenge do
      %LuohanZhen{
        fighter_id: "player:test",
        fighter_name: "测试玩家",
        fighter_room_id: "shaolin:wuchang",
        state: :preparing,
        master_asked: %{"xuanku" => true, "xuannan" => true},
        temp_flags: %{"xuanku-asked" => 1, "xuannan-asked" => 1},
        wait_time: 0,
        beat_count: 0,
        round: 0,
        timer_refs: %{},
        result: nil,
        assigned_by: "xuanku"
      }
    end

    test "返回 fighting 状态，round=0, beat_count=0" do
      c = preparing_challenge()

      {:ok, c2, effects} = LuohanZhen.preparing(c)

      assert c2.state == :fighting
      assert c2.round == 0
      assert c2.beat_count == 0
    end

    test "包含移走道觉僧、封锁出口、广播宣战、schedule :fighting 10s" do
      c = preparing_challenge()

      {:ok, _c2, effects} = LuohanZhen.preparing(c)

      assert any?(effects, fn {:move_npc, "shaolin_dao_jue", "shaolin:wuchang", "shaolin:houdian"} -> true; _ -> false end)
      assert any?(effects, fn {:delete_exit, "shaolin:wuchang", "north"} -> true; _ -> false end)
      assert any?(effects, fn {:delete_exit, "shaolin:wuchang", "south"} -> true; _ -> false end)
      assert any?(effects, fn {:delete_exit, "shaolin:wuchang", "east"} -> true; _ -> false end)
      assert any?(effects, fn {:delete_exit, "shaolin:wuchang", "west"} -> true; _ -> false end)
      assert any?(effects, fn {:schedule_timer, :fighting, 10_000} -> true; _ -> false end)
    end
  end

  describe "fighting/2 战斗状态" do
    defp fighting_challenge(overrides \\ %{}) do
      %LuohanZhen{
        fighter_id: "player:test",
        fighter_name: "测试玩家",
        fighter_room_id: "shaolin:wuchang",
        state: :fighting,
        master_asked: %{"xuanku" => true, "xuannan" => true},
        temp_flags: %{"xuanku-asked" => 1, "xuannan-asked" => 1},
        wait_time: 0,
        beat_count: 0,
        round: 0,
        timer_refs: %{},
        result: nil,
        assigned_by: "xuanku"
      } |> Map.merge(Map.new(overrides))
    end

    test "round=0 → 移入第1位罗汉，round=1，schedule :fighting 2s" do
      c = fighting_challenge(round: 0)

      {:ok, c2, effects} = LuohanZhen.fighting(c, 0)

      assert c2.round == 1
      assert any?(effects, fn {:move_npc, "shaolin_cheng_guan", _, "shaolin:wuchang"} -> true; _ -> false end)
      assert any?(effects, fn {:schedule_timer, :fighting, 2_000} -> true; _ -> false end)
    end

    test "round=1 → 移出第0位、移入第1位，round=2" do
      c = fighting_challenge(round: 1)

      {:ok, c2, effects} = LuohanZhen.fighting(c, 1)

      assert c2.round == 2
      assert any?(effects, fn {:move_npc, "shaolin_cheng_guan", "shaolin:wuchang", "shaolin:luohan1"} -> true; _ -> false end)
      assert any?(effects, fn {:move_npc, "shaolin_cheng_zhi", _, "shaolin:wuchang"} -> true; _ -> false end)
    end

    test "round=9, beat_count>=18 → result=:won, recruit_effects" do
      c = fighting_challenge(round: 9, beat_count: 18)

      {:ok, c2, effects} = LuohanZhen.fighting(c, 9)

      assert c2.state == :finished
      assert c2.result == :won
      assert any?(effects, fn {:schedule_timer, :do_back, 30_000} -> true; _ -> false end)
    end

    test "round=9, beat_count<18 → result=:lost, do_back_effects" do
      c = fighting_challenge(round: 9, beat_count: 17)

      {:ok, c2, effects} = LuohanZhen.fighting(c, 9)

      assert c2.state == :finished
      assert c2.result == :lost
      # do_back_effects contains broadcast, move_npc, delete_env, delete_temp, etc.
      assert any?(effects, fn {:broadcast, "shaolin:wuchang", _} -> true; _ -> false end)
      assert any?(effects, fn {:delete_env, "player:test", "assigned_fighter"} -> true; _ -> false end)
      refute any?(effects, fn {:schedule_timer, _, _} -> true; _ -> false end)
    end

    test "round<0 → {:error, :invalid_round}" do
      assert LuohanZhen.fighting(fighting_challenge(), -1) == {:error, :invalid_round}
    end

    test "round>9 → {:error, :invalid_round}" do
      assert LuohanZhen.fighting(fighting_challenge(), 10) == {:error, :invalid_round}
    end
  end

  describe "do_recruit/1 胜利奖励" do
    defp recruit_challenge(overrides \\ %{}) do
      %LuohanZhen{
        fighter_id: "player:test",
        fighter_name: "测试玩家",
        fighter_room_id: "shaolin:wuchang",
        state: :fighting,
        master_asked: %{"xuanku" => true, "xuannan" => true},
        temp_flags: %{"xuanku-asked" => 1, "xuannan-asked" => 1},
        wait_time: 0,
        beat_count: 18,
        round: 9,
        timer_refs: %{},
        result: nil,
        assigned_by: "xuanku"
      } |> Map.merge(Map.new(overrides))
    end

    test "同门少林玩家 → 恭喜文案 + 30s do_back" do
      c = recruit_challenge(fighter_room_id: "shaolin:wuchang")

      {:ok, _c2, effects} = LuohanZhen.do_recruit(c)

      assert any?(effects, fn {:add_combat_exp, "player:test", 7500} -> true; _ -> false end)
      assert any?(effects, fn {:set_env, "player:test", "luohan_winner", 1} -> true; _ -> false end)
      assert any?(
        effects,
        fn {:broadcast, "shaolin:wuchang", msg} -> is_binary(msg) and String.contains?(msg, "恭喜你闯过了十八罗汉大阵"); _ -> false end
      )
      assert any?(effects, fn {:schedule_timer, :do_back, 30_000} -> true; _ -> false end)
    end

    test "非少林玩家 → 当前状态机层均返回少林文案（Coordinator 层再区分）" do
      c = recruit_challenge(fighter_room_id: "wudang:tiyun")

      {:ok, _c2, effects} = LuohanZhen.do_recruit(c)

      # shaolin_fighter?/1 在状态机层恒返回 true（fighter.meta 未纳入 Challenge 结构），
      # 实际的同门/异门区分在 Coordinator 执行时完成
      assert any?(
        effects,
        fn {:broadcast, "shaolin:wuchang", msg} -> is_binary(msg) and String.contains?(msg, "恭喜你闯过了十八罗汉大阵"); _ -> false end
      )
      assert any?(effects, fn {:schedule_timer, :do_back, 30_000} -> true; _ -> false end)
    end
  end

  describe "do_back/1 终结重置" do
    test "返回 finished 状态和 do_back_effects" do
      c = %LuohanZhen{
        fighter_id: "player:test",
        state: :fighting,
        result: :won,
        master_asked: %{"xuanku" => true, "xuannan" => true},
        temp_flags: %{"xuanku-asked" => 1},
        wait_time: 0,
        beat_count: 18,
        round: 9,
        timer_refs: %{},
        assigned_by: "xuanku"
      }

      {:ok, c2, effects} = LuohanZhen.do_back(c)

      assert c2.state == :finished
      assert c2.result == :won
      assert any?(effects, fn {:move_npc, "shaolin_dao_jue", "shaolin:houdian", "shaolin:wuchang"} -> true; _ -> false end)
      assert any?(effects, fn {:delete_env, "player:test", "assigned_fighter"} -> true; _ -> false end)
    end
  end
end
