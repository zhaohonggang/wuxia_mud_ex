defmodule Kantele.Item.Effect.PillTest do
  @moduledoc """
  Unit tests for the data-driven pill planner (P5-5).

  Covers the LPC `do_effect(object me)` orchestration that the Elixir port models:
  cooldown gate, full-vital gate, heal-meta hand-off, and start_busy.
  """
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kantele.Item.Effect.Pill
  alias Kalevala.Character

  defp effect(overrides \\ %{}) do
    base = %{
      kind: "pill",
      cooldown: 5,
      cooldown_key: "last_eat/dan(A)",
      cooldown_text: "药力尚未化开，暂不能再服。",
      full_vital: "jing",
      full_text: "你现在精神状态充盈，无需服用。",
      vision_text: "{npc}吃下一粒丹药，灵台一片清净。",
      busy: 1,
      stack: true
    }

    Map.merge(base, overrides)
  end

  defp item(eff, medicine \\ %{jing: 100}) do
    %{id: "test:pill", name: "养精丹", meta: Map.put(%{medicine: medicine}, :effect, eff)}
  end

  defp character(vitals_overrides \\ %{}, cooldowns \\ %{}) do
    vitals =
      Map.merge(
        %Vitals{jing: 100, max_jing: 2000, qi: 1000, max_qi: 5000, jingli: 2000, max_jingli: 2000,
                neili: 9000, max_neili: 10000},
        vitals_overrides
      )

    %Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{vitals: vitals, combat: Combat.new(), pill_cooldowns: cooldowns}
    }
  end

  describe "plan/2 — 放行条件" do
    test "未达满状态且不在冷却 → 放行，携带 heal_meta" do
      {:ok, plan} = Pill.plan(character(), item(effect()))
      assert plan.heal_meta[:medicine][:jing] == 100
      assert plan.cooldown_secs == 5
      assert plan.cooldown_key == "last_eat/dan(A)"
      assert plan.full_vital == "jing"
      assert plan.busy == 1
      assert plan.vision_text =~ "{npc}"
    end

    test "满状态 → 拒绝 :full，返回 full_text" do
      {:reject, :full, text} = Pill.plan(character(%{jing: 2000}), item(effect()))
      assert text =~ "精神状态充盈"
    end

    test "处于冷却 → 拒绝 :cooldown，返回 cooldown_text" do
      cds = %{"last_eat/dan(A)" => System.system_time(:second)}
      {:reject, :cooldown, text} = Pill.plan(character(%{}, cds), item(effect()))
      assert text =~ "药力尚未化开"
    end

    test "无 cooldown / full 约束的简单丹药也能放行" do
      {:ok, plan} =
        Pill.plan(
          character(),
          item(effect(%{cooldown: nil, cooldown_key: nil, full_vital: nil}))
        )

      assert plan.cooldown_secs == nil
      assert plan.full_vital == nil
    end

    test "effect.kind 非 pill → 拒绝 :not_pill" do
      {:reject, :not_pill, _} = Pill.plan(character(), %{id: "x", meta: %{effect: %{kind: "food"}}})
    end

    test "无 effect → 拒绝 :not_pill" do
      {:reject, :not_pill, _} = Pill.plan(character(), %{id: "x", meta: %{}})
    end

    test "tell_object 自述（self_text）被保留" do
      eff = effect(%{vision_text: nil, self_text: "你只觉一股热流循环了一个周天。"})
      {:ok, plan} = Pill.plan(character(), item(eff))
      assert plan.self_text =~ "你只觉一股热流"
    end
  end

  describe "apply_cooldown/2" do
    test "有冷却则把时间戳写入 pill_cooldowns" do
      plan = %Pill{heal_meta: %{}, cooldown_key: "last_eat/dan(A)", cooldown_secs: 5}
      meta = Pill.apply_cooldown(%{}, plan)
      assert is_integer(Map.get(meta, :pill_cooldowns)["last_eat/dan(A)"])
    end

    test "无冷却则为 no-op" do
      plan = %Pill{heal_meta: %{}, cooldown_key: nil, cooldown_secs: nil}
      assert Pill.apply_cooldown(%{}, plan) == %{}
    end
  end

  describe "apply_busy/2" do
    test "有 busy 则累加到 combat" do
      plan = %Pill{heal_meta: %{}, busy: 2}
      combat = Pill.apply_busy(Combat.new(), plan)
      assert combat.busy >= 2
    end

    test "无 busy 则为 no-op（保持原 combat）" do
      plan = %Pill{heal_meta: %{}, busy: nil}
      combat = Pill.apply_busy(Combat.new(), plan)
      assert combat.busy == 0
    end
  end
end
