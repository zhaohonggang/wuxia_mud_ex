defmodule Kantele.Combat.SkillsValidLearnPartialBatch3Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次 3：

  arity-2 `valid_learn(stats, character)`（需 character/vitals/装备访问）：

  - `wuyue-blade`：max_neili>=600、force>=120、blade>=80、blade>=本门
  - `wuyun-jianfa`：max_neili>=400、force>=80
  - `xuanfeng-leg`：空手（无 weapon/secondary_weapon）、force>=80、max_neili>=400、unarmed>=本门
  - `xuantian-shengong`：force>=120、gender==无性 且 本门>49
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  defp stats(skills \\ %{}, attrs \\ %{}) do
    base = Stats.new()
    stats = %{base | skills: Map.merge(base.skills, skills)}
    Enum.reduce(attrs, stats, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp char(opts \\ []) do
    meta = %{
      vitals: %{
        max_neili: Keyword.get(opts, :max_neili, 20_000),
        neili: Keyword.get(opts, :neili, 20_000)
      },
      env: %{gender: Keyword.get(opts, :gender, "男性")},
      combat: %{equipped: Keyword.get(opts, :equipped, %{})}
    }
    %{meta: meta}
  end

  defp char_armed(opts \\ []) do
    %{
      meta: %{
        vitals: %{
          max_neili: Keyword.get(opts, :max_neili, 20_000),
          neili: Keyword.get(opts, :neili, 20_000)
        },
        env: %{gender: Keyword.get(opts, :gender, "男性")},
        combat: %{equipped: %{weapon: %{skill_type: "blade"}, secondary_weapon: nil}}
      }
    }
  end

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- wuyue-blade：max_neili / force / blade 门 ----

  test "wuyue-blade：max_neili < 600 → 拦" do
    assert_error("wuyue-blade", stats(%{"force" => 200, "blade" => 200, "wuyue-blade" => 100}), char(max_neili: 500), "你的内力不够")
  end

  test "wuyue-blade：force < 120 → 拦" do
    assert_error("wuyue-blade", stats(%{"force" => 100, "blade" => 200, "wuyue-blade" => 100}), char(max_neili: 1000), "内功火候太浅")
  end

  test "wuyue-blade：blade < 80 → 拦" do
    assert_error("wuyue-blade", stats(%{"force" => 200, "blade" => 50, "wuyue-blade" => 100}), char(max_neili: 1000), "基本刀法火候不够")
  end

  test "wuyue-blade：blade < 本门 → 拦" do
    assert_error("wuyue-blade", stats(%{"force" => 200, "blade" => 80, "wuyue-blade" => 100}), char(max_neili: 1000), "刀法水平有限")
  end

  test "wuyue-blade：全部达标 → :ok" do
    assert :ok = learn("wuyue-blade", stats(%{"force" => 200, "blade" => 200, "wuyue-blade" => 100}), char(max_neili: 1000))
  end

  test "wuyue-blade：max_neili 为 nil 时跳过该门（无 vitals 回落 arity-1）" do
    assert :ok = learn("wuyue-blade", stats(%{"force" => 200, "blade" => 200, "wuyue-blade" => 100}), %{meta: %{vitals: %{}, env: %{gender: "男性"}}})
  end

  # ---- wuyun-jianfa：max_neili / force 门 ----

  test "wuyun-jianfa：max_neili < 400 → 拦" do
    assert_error("wuyun-jianfa", stats(%{"force" => 200, "wuyun-jianfa" => 100}), char(max_neili: 300), "你的内力不够")
  end

  test "wuyun-jianfa：force < 80 → 拦" do
    assert_error("wuyun-jianfa", stats(%{"force" => 50, "wuyun-jianfa" => 100}), char(max_neili: 1000), "内功火候不够")
  end

  test "wuyun-jianfa：全部达标 → :ok" do
    assert :ok = learn("wuyun-jianfa", stats(%{"force" => 200, "wuyun-jianfa" => 100}), char(max_neili: 1000))
  end

  # ---- xuanfeng-leg：空手 / force / max_neili / unarmed 门 ----

  test "xuanfeng-leg：持兵器 → 拦" do
    assert_error("xuanfeng-leg", stats(%{"force" => 200, "unarmed" => 200, "xuanfeng-leg" => 100}), char_armed(max_neili: 1000), "必须空手")
  end

  test "xuanfeng-leg：force < 80 → 拦" do
    assert_error("xuanfeng-leg", stats(%{"force" => 50, "unarmed" => 200, "xuanfeng-leg" => 100}), char(max_neili: 1000), "内功火候不够")
  end

  test "xuanfeng-leg：max_neili < 400 → 拦" do
    assert_error("xuanfeng-leg", stats(%{"force" => 200, "unarmed" => 200, "xuanfeng-leg" => 100}), char(max_neili: 300), "内力太弱")
  end

  test "xuanfeng-leg：unarmed < 本门 → 拦" do
    assert_error("xuanfeng-leg", stats(%{"force" => 200, "unarmed" => 50, "xuanfeng-leg" => 100}), char(max_neili: 1000), "基本拳脚水平有限")
  end

  test "xuanfeng-leg：全部达标（空手） → :ok" do
    assert :ok = learn("xuanfeng-leg", stats(%{"force" => 200, "unarmed" => 200, "xuanfeng-leg" => 100}), char(max_neili: 1000))
  end

  # ---- xuantian-shengong：force / gender 门 ----

  test "xuantian-shengong：force < 120 → 拦" do
    assert_error("xuantian-shengong", stats(%{"force" => 100, "xuantian-shengong" => 30}), char(max_neili: 1000), "基本内功火候还不够")
  end

  test "xuantian-shengong：gender 无性 且 本门 > 49 → 拦" do
    assert_error("xuantian-shengong", stats(%{"xuantian-shengong" => 50, "force" => 200}), char(max_neili: 1000, gender: "无性"), "无根无性")
  end

  test "xuantian-shengong：gender 无性 且 本门 <= 49 → 通过（性别门不触发）" do
    assert :ok = learn("xuantian-shengong", stats(%{"xuantian-shengong" => 49, "force" => 200}), char(max_neili: 1000, gender: "无性"))
  end

  test "xuantian-shengong：gender 男性 且 force 达标 → :ok" do
    assert :ok = learn("xuantian-shengong", stats(%{"xuantian-shengong" => 100, "force" => 200}), char(max_neili: 1000, gender: "男性"))
  end

  # ---- 覆盖性：4 个 arity-2 技能均已注册并导出 valid_learn/2 ----

  test "4 个 arity-2 技能均已注册并可调用 valid_learn/2" do
    for id <- ~w(wuyue-blade wuyun-jianfa xuanfeng-leg xuantian-shengong) do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end

  test "任意角色形状下不抛异常" do
    shapes = [
      %{},
      char(),
      char(gender: "无性"),
      char_armed(),
      %{meta: %{vitals: %{max_neili: nil, neili: nil}, env: %{gender: nil}}},
      %{meta: %{vitals: %{max_neili: 1000, neili: 1000}, env: %{gender: "无性"}}}
    ]

    for id <- ~w(wuyue-blade wuyun-jianfa xuanfeng-leg xuantian-shengong), shape <- shapes do
      case learn(id, stats(), shape) do
        :ok -> :ok
        {:error, message} -> assert is_binary(message) and message != ""
        other -> flunk("#{id} 返回了非法值：#{inspect(other)}")
      end
    end
  end
end
