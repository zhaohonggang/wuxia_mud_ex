defmodule Kantele.Combat.SkillsValidLearnPilotTest do
  @moduledoc """
  F4 valid_learn 长尾补全——试点批（确认 arity-1 / arity-2 _character / 隐藏 arity-1 边界）。

  对照口径（与既有批次一致）：
  - `me->query("gender")` → `meta.env[:gender]`（缺字段按「男性」）
  - `me->query("max_neili")` → `meta.vitals.max_neili`（vitals，仅 arity-2 可访问）
  - `me->query_temp("weapon")/("secondary_weapon")` → `Skill.wielding?/secondary_wielding?`
  - `weapon->query("skill_type")` → `Skill.wielded_skill_type/1`
  - `me->query_skill(X, 1)` → `Stats.skill(stats, X)`（基本技能不折半）
  - `me->query("con")` → `Stats.query_con(stats)`（派生根骨，**非原始** stats.con）

  试点选取：
  - 隐藏 arity-1（仅需 stats 派生，应 arity-1）：xuanming-shengong（con + force）
  - 隐藏 arity-2（性别门，`::valid_learn` 回落）：kuihua-xinfa
  - 隐藏 arity-2（vitals + 武器 + 技能门，`return 1`）：huashan-sword
  - 隐藏 arity-2（空手 + force + vitals + 技能门）：wuxing-quan
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

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- xuanming-shengong：arity-1（con 在 Stats 内，派生根骨） ----

  test "xuanming-shengong：派生根骨 query_con < 32 → 拦" do
    # Stats.new 默认 con=20, force=20 → query_con = 20 + 20/10 = 22 < 32
    assert_error("xuanming-shengong", stats(), char(), "你先天根骨不足，无法修炼玄冥神功")
  end

  test "xuanming-shengong：force < 100 → 拦" do
    # con=30 抬升 query_con 过 32（30 + force/10 = 32），但 force 技能仍 < 100
    s = stats(%{"force" => 20}, con: 30)
    assert_error("xuanming-shengong", s, char(), "你的基本内功火候还不够，还不能学习玄冥神功")
  end

  test "xuanming-shengong：派生根骨与 force 双达标 → :ok" do
    # con=30, force 技能=200 → query_con = 30 + 20 = 50 ≥ 32；force 技能 ≥ 100
    s = stats(%{"force" => 200}, con: 30)
    assert :ok = learn("xuanming-shengong", s, char())
  end

  # ---- kuihua-xinfa：arity-2 性别门（`::valid_learn` 回落） ----

  test "kuihua-xinfa：非「无性」→ 拦" do
    for gender <- ["男性", "女性"] do
      assert_error("kuihua-xinfa", stats(), char(gender: gender), "欲练神功，挥刀自宫")
    end
  end

  test "kuihua-xinfa：「无性」→ 放行" do
    assert :ok = learn("kuihua-xinfa", stats(), char(gender: "无性"))
  end

  test "kuihua-xinfa：缺 env / 为 nil → 按「男性」拒绝" do
    assert {:error, _} = learn("kuihua-xinfa", stats(), %{})
    assert {:error, _} = learn("kuihua-xinfa", stats(), %{meta: %{}})
  end

  # ---- huashan-sword：arity-2（max_neili + 必须持剑 + 剑法等级） ----

  test "huashan-sword：max_neili < 100 → 拦" do
    assert_error("huashan-sword", stats(%{"sword" => 200, "huashan-sword" => 10}),
      char(max_neili: 50, equipped: %{weapon: %{skill_type: "sword"}}),
      "你的内力不够，没有办法练华山剑法")
  end

  test "huashan-sword：未持武器 → 拦" do
    assert_error("huashan-sword", stats(%{"sword" => 200, "huashan-sword" => 10}),
      char(equipped: %{}), "你必须先找一把剑才能学习剑法")
  end

  test "huashan-sword：持非剑武器 → 拦" do
    assert_error("huashan-sword", stats(%{"sword" => 200, "huashan-sword" => 10}),
      char(equipped: %{weapon: %{skill_type: "blade"}}), "你必须先找一把剑才能学习剑法")
  end

  test "huashan-sword：持剑但剑法 < 本门等级 → 拦" do
    assert_error("huashan-sword", stats(%{"sword" => 5, "huashan-sword" => 10}),
      char(equipped: %{weapon: %{skill_type: "sword"}}),
      "你的基本剑法火候有限，无法领会更高深的华山剑法")
  end

  test "huashan-sword：持剑 + 剑法达标 → :ok" do
    assert :ok =
             learn("huashan-sword", stats(%{"sword" => 200, "huashan-sword" => 10}),
               char(equipped: %{weapon: %{skill_type: "sword"}})
             )
  end

  # ---- wuxing-quan：arity-2（空手 + force + max_neili + 拳脚） ----

  test "wuxing-quan：持武器（非空手）→ 拦" do
    assert_error("wuxing-quan", stats(%{"force" => 200, "unarmed" => 200, "wuxing-quan" => 10}),
      char(equipped: %{weapon: %{}}), "练五行拳必须空手")
  end

  test "wuxing-quan：force < 100 → 拦" do
    assert_error("wuxing-quan", stats(%{"unarmed" => 200, "wuxing-quan" => 10}),
      char(), "你的内功火候不够，无法学五行拳")
  end

  test "wuxing-quan：max_neili < 800 → 拦" do
    assert_error("wuxing-quan", stats(%{"force" => 200, "unarmed" => 200, "wuxing-quan" => 10}),
      char(max_neili: 500), "你的内力太弱，无法练五行拳")
  end

  test "wuxing-quan：unarmed < 100 → 拦" do
    assert_error("wuxing-quan", stats(%{"force" => 200, "unarmed" => 50, "wuxing-quan" => 10}),
      char(), "你的拳脚根基有限，无法体会五行拳要诣")
  end

  test "wuxing-quan：unarmed < 本门等级 → 拦" do
    # unarmed=150 已过 <100 门，但仍 < wuxing-quan(200) 等级门
    assert_error("wuxing-quan", stats(%{"force" => 200, "unarmed" => 150, "wuxing-quan" => 200}),
      char(), "你的拳脚根基火候不足，无法领会更高深的五行拳")
  end

  test "wuxing-quan：全部达标（空手）→ :ok" do
    assert :ok =
             learn("wuxing-quan",
               stats(%{"force" => 200, "unarmed" => 200, "wuxing-quan" => 10}),
               char()
             )
  end

  # ---- 注册覆盖 ----

  test "4 个试点技能均已注册并导出 valid_learn/2" do
    for id <- ~w(xuanming-shengong kuihua-xinfa huashan-sword wuxing-quan) do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end
end
