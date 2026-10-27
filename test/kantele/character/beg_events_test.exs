defmodule Kantele.Character.BegEventsTest do
  @moduledoc """
  P5 乞讨跨进程结算事件单测（对应 LPC `ob->set_amount` / `improve_skill` /
  `add("potential")` / `start_busy`）。

  - `BegDebitEvent`：victim 进程扣币（不低于 0）。
  - `BegCreditEvent`：beggar 进程成功 → 加币 + 技能 + 潜能 + 实战 + 忙乱；
    失败（fail_roll/fail_ignore）→ 仅忙乱、币与技能不变。
  """
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BegCreditEvent
  alias Kantele.Character.BegDebitEvent
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(coins) do
    %Kalevala.Character{
      id: "player-1",
      name: "小乞丐",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{"jing" => 200},
      meta: %PlayerMeta{
        family: %{name: "丐帮"},
        stats: %Stats{skills: %{}, potential: 100, combat_exp: 1000},
        vitals: %Vitals{qi: 500, max_qi: 500, jing: 200, max_jing: 200, neili: 100, max_neili: 100},
        combat: Combat.new(),
        coins: coins
      }
    }
  end

  defp updated(conn), do: conn.private.update_character || conn.character

  describe "BegDebitEvent（victim 扣币）" do
    test "扣减指定金额且不低于 0" do
      conn = build_conn(player(500))
      conn = BegDebitEvent.run(conn, %{data: %{amount: 100}})
      assert updated(conn).meta.coins == 400
    end

    test "金额超过余额时只扣到 0" do
      conn = build_conn(player(30))
      conn = BegDebitEvent.run(conn, %{data: %{amount: 100}})
      assert updated(conn).meta.coins == 0
    end

    test "金额为 0 时不改动" do
      conn = build_conn(player(50))
      conn = BegDebitEvent.run(conn, %{data: %{amount: 0}})
      assert updated(conn).meta.coins == 50
    end
  end

  describe "BegCreditEvent（beggar 结算）" do
    test "成功：加币 + 技能升级 + 潜能/实战 +1 + 忙乱 3~6 轮" do
      conn = build_conn(player(0))
      conn = BegCreditEvent.run(conn, %{data: %{result: :success, amount: 100}})

      meta = updated(conn).meta
      assert meta.coins == 100
      assert meta.stats.skills["begging"] == 1
      assert meta.stats.potential == 101
      assert meta.stats.combat_exp == 1001
      assert meta.combat.busy >= 3 and meta.combat.busy <= 6
    end

    test "失败 fail_roll：仅忙乱 3 轮，币与技能不变" do
      conn = build_conn(player(0))
      conn = BegCreditEvent.run(conn, %{data: %{result: :fail_roll, amount: 0}})

      meta = updated(conn).meta
      assert meta.coins == 0
      assert meta.stats.skills["begging"] == nil
      assert meta.combat.busy == 3
    end

    test "失败 fail_ignore：仅忙乱 3 轮，币与技能不变" do
      conn = build_conn(player(0))
      conn = BegCreditEvent.run(conn, %{data: %{result: :fail_ignore, amount: 0}})

      meta = updated(conn).meta
      assert meta.coins == 0
      assert meta.stats.skills["begging"] == nil
      assert meta.combat.busy == 3
    end
  end
end
