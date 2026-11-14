defmodule Kantele.NPC.HunterTeachTest do
  @moduledoc """
  衡阳猎人 `ask hunter about hunting` 教学收益对齐 LPC。

  LPC `hunter.c::teach_hunting`：`add = query_int() + random(query_int()/2)`，
  再 `improve_skill("hunting", add)` —— add 是「点数」，显示等级 = floor(sqrt(累计点数))。
  EX 早期误把 add 当「等级」直接 set_skill(原等级 + add)，导致一次教学暴涨 ~26 级。

  本测试锁定：教学走 sqrt 曲线（点数 = 等级² 估算），而非线性 +add。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.NPC.Hunter

  defp asker(int, hunting_level) do
    base = Stats.new()
    stats = %{base | int: int, skills: Map.put(base.skills, "hunting", hunting_level)}

    # 用裸 map 构造 meta（hunter_mark?/stats_of/vitals_of 均兼容裸 map，
    # 且可避免 PlayerMeta.vitals 默认 nil 触发 teach 内 Map.get(nil, ...)）。
    %{
      meta: %{
        marks: %{"hunter" => 1},
        stats: stats,
        vitals: %{jing: 100}
      }
    }
  end

  describe "ask hunter about hunting（对齐 LPC 的 sqrt 曲线）" do
    test "收益走 sqrt 曲线，而非线性 +add（int=4 → 2 级，而非 4/5 级）" do
      # int=4 → half=2 → bonus = random(2)-1 ∈ {0,1} → add ∈ {4,5}
      # floor(sqrt(4)) = 2，floor(sqrt(5)) = 2 → 恒为 2 级（确定性）
      # 旧版线性写法是 0 + add = 4 或 5 级 → 必须排除
      {:ok, _msg, new_asker} = Hunter.execute(asker(4, 0), %{}, "hunting")
      level = Stats.skill(new_asker.meta.stats, "hunting")

      assert level == 2
      refute level in [4, 5]
    end

    test "高等级时单次教学收益递减（LPC 累计点数门槛）" do
      # 已满 10 级（≈100 点），再加 add(4..5) → 仍 < 121（11 级门槛）→ 维持 10 级
      {:ok, _msg, new_asker} = Hunter.execute(asker(4, 10), %{}, "hunting")
      level = Stats.skill(new_asker.meta.stats, "hunting")

      assert level == 10
    end

    test "未给捕兽夹（无 marks/hunter）时拒绝教学" do
      base = Stats.new()
      asker = %{meta: %{stats: %{base | int: 4}}}

      assert {:error, _} = Hunter.execute(asker, %{}, "hunting")
    end
  end
end
