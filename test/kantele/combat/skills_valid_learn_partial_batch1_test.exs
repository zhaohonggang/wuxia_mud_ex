defmodule Kantele.Combat.SkillsValidLearnPartialBatch1Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次 1：

  从 arity-1 占位升级为 arity-2（补齐 LPC 的 character/vitals 门槛）：

  - `linji-zhuang`：LPC `gender != 女性` → `notify_fail("你非女子，不能练习临济十二庄。\n")`
  - `longxiang-gong`：LPC `str < 36` / `con < 30` / `gender == 无性 && layer >= 1`
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

  # ---- linji-zhuang：性别门（必须女性） ----

  test "linji-zhuang：gender 男性/无性/nil → 拦" do
    assert_error("linji-zhuang", stats(%{"force" => 100, "mahayana" => 300}), char(gender: "男性"), "你非女子")
    assert_error("linji-zhuang", stats(%{"force" => 100, "mahayana" => 300}), char(gender: "无性"), "你非女子")
    assert_error("linji-zhuang", stats(%{"force" => 100, "mahayana" => 300}), char(), "你非女子")
  end

  test "linji-zhuang：gender 女性，force/mahayana 够 → :ok" do
    assert :ok =
             learn(
               "linji-zhuang",
               stats(%{"force" => 100, "mahayana" => 300}),
               char(gender: "女性")
             )
  end

  test "linji-zhuang：gender 女性，force < 40 → 拦" do
    assert_error("linji-zhuang", stats(%{"force" => 39, "mahayana" => 300}), char(gender: "女性"), "基本内功火候还不够")
  end

  test "linji-zhuang：gender 女性，mahayana 不够 → 拦" do
    assert_error(
      "linji-zhuang",
      stats(%{"force" => 100, "linji-zhuang" => 100, "mahayana" => 50}),
      char(gender: "女性"),
      "大乘涅磐功修为不够"
    )
  end

  # ---- longxiang-gong：str/con/性别门 ----

  test "longxiang-gong：str < 36 → 拦" do
    assert_error(
      "longxiang-gong",
      stats(%{"force" => 200}, %{str: 35, con: 40}),
      char(),
      "先天膂力孱弱"
    )
  end

  test "longxiang-gong：con < 30 → 拦" do
    assert_error(
      "longxiang-gong",
      stats(%{"force" => 200}, %{str: 40, con: 29}),
      char(),
      "先天根骨孱弱"
    )
  end

  test "longxiang-gong：gender 无性且 layer >= 1（lvl >= 30）→ 拦" do
    assert_error(
      "longxiang-gong",
      stats(%{"longxiang-gong" => 30, "force" => 200, "lamaism" => 200}, %{str: 40, con: 40}),
      char(gender: "无性"),
      "无根无性"
    )
  end

  test "longxiang-gong：str/con 够，gender 非无性，force/lamaism 够 → :ok" do
    assert :ok =
             learn(
               "longxiang-gong",
               stats(%{"longxiang-gong" => 30, "force" => 200, "lamaism" => 200}, %{str: 40, con: 40}),
               char(gender: "男性")
             )
  end

  test "longxiang-gong：force < 100 → 拦（arity-1 回落保持）" do
    assert_error(
      "longxiang-gong",
      stats(%{"force" => 99}, %{str: 40, con: 40}),
      char(),
      "基本内功火候不足"
    )
  end

  # ---- 覆盖性：两个技能都已注册且 valid_learn/2 可调用 ----

  test "linji-zhuang / longxiang-gong 已注册并导出 valid_learn/2" do
    for id <- ~w(linji-zhuang longxiang-gong) do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end

  test "任意角色形状下不抛异常" do
    shapes = [
      %{},
      char(),
      char(gender: "无性"),
      char(gender: "女性"),
      %{meta: %{vitals: %{max_neili: nil, neili: nil}, env: %{gender: nil}}},
      %{meta: %{vitals: %{max_neili: 1000, neili: 1000}, env: %{gender: "无性"}}}
    ]

    for id <- ~w(linji-zhuang longxiang-gong), shape <- shapes do
      case learn(id, stats(), shape) do
        :ok -> :ok
        {:error, message} -> assert is_binary(message) and message != ""
        other -> flunk("#{id} 返回了非法值：#{inspect(other)}")
      end
    end
  end
end
