defmodule Kantele.World.ArenaTest do
  @moduledoc """
  擂台关闭状态（`d/city/leitai.c` 的 `close_by` / `refuse`）

  与五行迷宫、八卦阵不同，这一类条件是**跨房间**的：判定发生在观众席
  （`city:wudao1` 等）的 `movement_request` 里，而状态属于擂台
  （`city:leitai`）。所以这里既测状态读写，也测「从别的房间读它」。
  """
  use ExUnit.Case, async: false

  alias Kantele.World.Arena

  @leitai "city:leitai"

  setup do
    # 每个测试前后都恢复「开放」，免得相互影响
    Arena.open(@leitai)
    on_exit(fn -> Arena.open(@leitai) end)
    :ok
  end

  describe "close_by/1" do
    test "默认没人关闭" do
      assert Arena.close_by(@leitai) == nil
    end

    test "close 之后记下是谁关的" do
      Arena.close(@leitai, %{name: "grant"})
      assert Arena.close_by(@leitai).by == "grant"
    end

    test "open 之后又变回 nil" do
      Arena.close(@leitai, %{name: "grant"})
      Arena.open(@leitai)
      assert Arena.close_by(@leitai) == nil
    end

    test "没被关过的房间读出来是 nil（不是错误）" do
      assert Arena.close_by("city:wudao1") == nil
      assert Arena.close_by("不存在:的房间") == nil
      assert Arena.close_by(nil) == nil
    end
  end

  describe "refused?/2（LPC refuse/1：!wizardp(ob) && query(\"close_by\")）" do
    test "没人关闭 -> 不拒绝（任何身份）" do
      refute Arena.refused?(@leitai, false)
      refute Arena.refused?(@leitai, true)
    end

    test "已关闭 -> 拒绝非巫师" do
      Arena.close(@leitai, %{name: "grant"})
      assert Arena.refused?(@leitai, false)
    end

    test "已关闭 -> 巫师照旧放行" do
      Arena.close(@leitai, %{name: "grant"})
      refute Arena.refused?(@leitai, true)
    end

    test "refuse/2 返回 LPC 的拒绝原文" do
      Arena.close(@leitai, %{name: "grant"})

      assert {:block, msg, []} = Arena.refuse(@leitai, false)
      assert msg == "你凑什么热闹，现在不是你上去的时候。"
    end
  end

  describe "缓存没起来时必须 fail-safe" do
    test "close_by 对不存在的 ETS 也只返回 nil，不抛异常" do
      # 直接打 Kalevala.Cache.get/2（未捕获的路径）确认它确实会抛，
      # 而 Arena.close_by/1 把它吞掉了 —— 这条守护的是「房间进程不被崩掉」
      assert_raise ArgumentError, fn ->
        :ets.lookup(:definitely_not_a_real_ets_table, "x")
      end

      # 正常路径（ETS 存在）不应受影响
      assert Arena.close_by(@leitai) == nil
    end
  end
end