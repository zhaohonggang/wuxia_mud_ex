defmodule Kantele.World.SeasonEventTest do
  use ExUnit.Case, async: true

  alias Kantele.World.SeasonEvent

  defp candidate(overrides \\ []) do
    %{
      pid: self(),
      outdoors?: Keyword.get(overrides, :outdoors?, true),
      con: Keyword.get(overrides, :con, 20),
      warm: Keyword.get(overrides, :warm, 0),
      player?: Keyword.get(overrides, :player?, true)
    }
  end

  # 各次调用依次返回 values 里的数（模拟 LPC random(max) 返回 0..max-1）
  defp seq_rng(values) do
    :erlang.put(:season_rng_vals, values)
    :erlang.put(:season_rng_i, 0)
    fn _max ->
      vals = :erlang.get(:season_rng_vals)
      i = :erlang.get(:season_rng_i)
      :erlang.put(:season_rng_i, i + 1)
      Enum.at(vals, i) || 0
    end
  end

  describe "plan_noon/3 —— 正午发病指令（纯函数，零 I/O 依赖）" do
    test "random(4) != 0 时不发病（3/4 空拦，与 LPC 一致）" do
      rng = seq_rng([3])  # gate: 3 != 0 -> 返回 []
      assert [] = SeasonEvent.plan_noon(4, [candidate()], rng)
    end

    test "spring（3-5月）：ill_kesou，ic=5" do
      pid = self()
      # gate=0(过), fashao=1(不过), con=20 -> con_resist=10+0=10, con+ic=15 < 25 -> 发病
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(4, [candidate()], rng)

      assert [%{pid: ^pid, cnd: "ill_kesou", duration: _, announce: _}] = result
    end

    test "summer（6-8月）：ill_zhongshu" do
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(7, [candidate()], rng)

      assert [%{cnd: "ill_zhongshu", announce: _}] = result
    end

    test "autumn（9-11月）：ill_shanghan" do
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(10, [candidate()], rng)

      assert [%{cnd: "ill_shanghan", announce: _}] = result
    end

    test "winter（12,1,2月）：ill_dongshang" do
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(1, [candidate()], rng)

      assert [%{cnd: "ill_dongshang", announce: _}] = result
    end

    test "fashao 覆盖：两次 random(4) 都为 0" do
      rng = seq_rng([0, 0])  # gate 过 + fashao 覆盖
      result = SeasonEvent.plan_noon(4, [candidate()], rng)

      assert [%{cnd: "ill_fashao", announce: _}] = result
    end

    test "非玩家（pid 非 player:*）：不落病" do
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(4, [candidate(player?: false)], rng)

      assert [] = result
    end

    test "非户外房间：不落病" do
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(4, [candidate(outdoors?: false)], rng)

      assert [] = result
    end

    test "体质抗力达标（con+ic >= 25）：不落病" do
      # kesou ic=5，con=20 -> con_resist=10+0=10，con+ic=15 < 25 会发病
      # 改 con=30 -> con_resist=15+0=15，con+ic=20 < 25 仍发病
      # con=40 -> con_resist=20+0=20，con+ic=25 不 < 25，不发病
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(4, [candidate(con: 40)], rng)

      assert [] = result
    end

    test "体质抗力不达标：duration = 30 - con" do
      # con=20 -> con_resist=10，con+ic=15 < 25 -> duration = 30-10=20
      rng = seq_rng([0, 1])
      result = SeasonEvent.plan_noon(4, [candidate(con: 20)], rng)

      assert [%{duration: 20}] = result
    end

    test "多个候选角色分别计算，不符合的过滤掉" do
      rng = seq_rng([0, 1, 0, 1])
      cands = [
        candidate(con: 20),        # 发病 (con+ic=15<25)
        candidate(outdoors?: false), # 不户外，跳过
        candidate(player?: false),   # 非玩家，跳过
        candidate(con: 40)           # 抗力达标，不发病
      ]
      result = SeasonEvent.plan_noon(4, cands, rng)

      assert length(result) == 1
      assert hd(result).cnd == "ill_kesou"
    end
  end

  describe "illness_for_month/1 —— 月份到病种映射" do
    test "3/4/5 -> kesou" do
      assert {"ill_kesou", 5, _} = SeasonEvent.illness_for_month(3)
      assert {"ill_kesou", 5, _} = SeasonEvent.illness_for_month(5)
    end

    test "6/7/8 -> zhongshu" do
      assert {"ill_zhongshu", 5, _} = SeasonEvent.illness_for_month(6)
      assert {"ill_zhongshu", 5, _} = SeasonEvent.illness_for_month(8)
    end

    test "9/10/11 -> shanghan" do
      assert {"ill_shanghan", 5, _} = SeasonEvent.illness_for_month(9)
      assert {"ill_shanghan", 5, _} = SeasonEvent.illness_for_month(11)
    end

    test "12/1/2 -> dongshang, ic=0" do
      assert {"ill_dongshang", 0, _} = SeasonEvent.illness_for_month(12)
      assert {"ill_dongshang", 0, _} = SeasonEvent.illness_for_month(1)
      assert {"ill_dongshang", 0, _} = SeasonEvent.illness_for_month(2)
    end
  end

  describe "adjust_warm —— 按病种加减 warm（端口未建模 warm 恒为 0，分支保留）" do
    test "shanghan/dongshang 加 warm，zhongshu 减 warm" do
      assert 12 = SeasonEvent.adjust_warm(10, 2, "ill_shanghan")
      assert 12 = SeasonEvent.adjust_warm(10, 2, "ill_dongshang")
      assert 8 = SeasonEvent.adjust_warm(10, 2, "ill_zhongshu")
      assert 10 = SeasonEvent.adjust_warm(10, 2, "ill_kesou")
      assert 10 = SeasonEvent.adjust_warm(10, 2, "ill_fashao")
    end
  end
end
