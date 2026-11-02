defmodule Kantele.Combat.SkillsValidLearnBatch6Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次6（DOOR_MISMATCH 中可实施部分，2 个技能）。
  对照 LPC `valid_learn` 体补齐缺失门槛（仅补「非持械存在门」，即 mark / 派生属性 /
  技能等级门；持械存在门按本仓约定由 practice 流程把关，见下）：

    - dugu-jiujian    : mark `can_learn/dugu-jiujian/nothing` + con<36 + dex<36
    - jiuyang-shengong: mark `can_learn/jiuyang-shengong/enable_weapon` + sword<lvl + blade<lvl
                        （注意 sword/blade 是**技能等级**门，非持械存在门）

  **不纳入本批（持械存在门，按本仓既有约定由 practice 流程把关，不写入 valid_learn）**：

    - qingyun-bian   : LPC `!weapon || skill_type != "whip"`（须持鞭）——见 qingyun_bian.ex
                       moduledoc「未建模」段与 bagua_dao.ex 同款约定；
    - tiangang-zhi   : LPC `query_temp("weapon") || query_temp("secondary_weapon")`（须空手）——
                       见 skills_tiangang_zhi_test.exs 注释「由 practice 流程把关」。

  另 3 个 DOOR_MISMATCH（daojian-guizhen / sanwu-shou / xixing-dafa）含 `query("character")`
  性格门且 meta.env 未建模 personality，与 15 个 HIDDEN_A2 一并暂缓；wudoumi-shengong 的
  personality 为排除门（`!=心狠手辣 && !=国士无双`→拦）同理暂缓；
  hunyuan-yiqi（guilty 未建模）、qiankun-danuoyi（query_condition 未建模）已忠实，无需改动。
  """
  use ExUnit.Case, async: true
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  # 派生属性（str/int/dex/con/per）走 struct 字段；其余一律当作技能等级放 :skills。
  # 未显式给出的派生属性默认给 100（足够通过门槛），仅“目标门槛测试”会显式给低值。
  @stat_keys ["str", "int", "dex", "con", "per"]
  @stat_default 100

  defp stats(map) do
    provided = MapSet.new(for({k, _} <- map, k in @stat_keys, do: k))

    base =
      Enum.reduce(map, Stats.new(), fn
        {k, v}, acc when k in @stat_keys -> Map.put(acc, String.to_atom(k), v)
        {_k, _v}, acc -> acc
      end)

    base =
      Enum.reduce(@stat_keys, base, fn k, acc ->
        if MapSet.member?(provided, k), do: acc, else: Map.put(acc, String.to_atom(k), @stat_default)
      end)

    skills = Map.new(for({k, v} <- map, not (k in @stat_keys), do: {k, v}))
    Map.put(base, :skills, skills)
  end

  defp char(opts),
    do: %{
      meta: %{
        vitals: %{max_neili: Keyword.get(opts, :max_neili, 20000)},
        env: %{gender: Keyword.get(opts, :gender, "男性")},
        combat: %{equipped: Keyword.get(opts, :equipped, %{})}
      },
      marks: Keyword.get(opts, :marks, %{})
    }

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- 注册健全性 ----
  test "2 个批次6 技能均已在 Skills 注册且导出 valid_learn/2" do
    for id <- ["dugu-jiujian", "jiuyang-shengong"] do
      assert Skills.get(id) != nil, "未注册: #{id}"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "缺 valid_learn/2: #{id}"
    end
  end

  # ---- dugu-jiujian ----
  test "dugu-jiujian：全达标（持剑/int足/sword足/无 mark）→ :ok" do
    assert :ok =
             learn(
               "dugu-jiujian",
               stats(%{"sword" => 200, "dugu-jiujian" => 100}),
               char(equipped: %{weapon: %{skill_type: "sword"}})
             )
  end

  test "dugu-jiujian：门 can_learn mark + con<36 + dex<36 → 拦" do
    assert_error(
      "dugu-jiujian",
      stats(%{"sword" => 200, "dugu-jiujian" => 100, "con" => 20, "dex" => 20}),
      char(
        equipped: %{weapon: %{skill_type: "sword"}},
        marks: %{"can_learn/dugu-jiujian/nothing" => 1}
      ),
      "你先天根骨或身法不足，无法体会独孤九剑的剑意。"
    )
  end

  # ---- jiuyang-shengong ----
  test "jiuyang-shengong：全达标 → :ok" do
    assert :ok =
             learn(
               "jiuyang-shengong",
               stats(%{
                 "force" => 300,
                 "unarmed" => 300,
                 "martial-cognize" => 200,
                 "jiuyang-shengong" => 200
               }),
               char(max_neili: 5000)
             )
  end

  test "jiuyang-shengong：门 enable_weapon mark + sword/blade<lvl → 拦" do
    assert_error(
      "jiuyang-shengong",
      stats(%{
        "force" => 300,
        "unarmed" => 300,
        "martial-cognize" => 200,
        "sword" => 100,
        "blade" => 100,
        "jiuyang-shengong" => 200
      }),
      char(max_neili: 5000, marks: %{"can_learn/jiuyang-shengong/enable_weapon" => 1}),
      "你对刀剑功夫的理解还不够，无法继续领会更高深的九阳神功。"
    )
  end
end
