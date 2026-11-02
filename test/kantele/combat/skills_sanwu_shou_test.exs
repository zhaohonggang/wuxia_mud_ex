defmodule Kantele.Combat.SkillsSanwuShouTest do
  @moduledoc """
  三无三不手学习门槛迁移（C 相位，sanwu-shou 真缺口补齐）。

  对照 `kungfu/skill/sanwu-shou.c`：
  - valid_learn: 性格须「心狠手辣」或「国士无双」（**首门**）/ max_neili>=800 / force>=120 /
    whip>=100 / whip>=sanwu-shou；
  - 性格门读 `meta.character`（LPC `query("character")`）；LPC 未设时为 0 → **拒**
    （源里赋値点只有 `d/register/npc/li.c` 与 `adm/daemons/updated.c:515` 转世「国士无双」）；
  - practice_skill 扣 qi 55 / neili 60（须持鞭由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SanwuShou

  defp stats(force, whip, self_lvl) do
    %{skills: %{"force" => force, "whip" => whip, "sanwu-shou" => self_lvl}}
  end

  # 默认给通过性格门的「心狠手辣」
  defp char(mn, personality \\ "心狠手辣"),
    do: %{
      meta: %{
        vitals: %{max_neili: mn},
        character: personality,
        combat: %{equipped: %{weapon: %{skill_type: "whip"}}}
      }
    }

  describe "valid_learn/2 性格门（LPC query(\"character\") 须心狠手辣或国士无双）" do
    test "性格为「光明磊落」被拒（性格门在持鞭门之前）" do
      assert SanwuShou.valid_learn(stats(200, 200, 10), char(800, "光明磊落")) ==
               {:error, "练三无三不手必须要心狠手辣，我看你这点做得还不够。\n"}
    end

    test "性格未设（nil）按 LPC「未设即 0」拒" do
      assert SanwuShou.valid_learn(stats(200, 200, 10), char(800, nil)) ==
               {:error, "练三无三不手必须要心狠手辣，我看你这点做得还不够。\n"}
    end

    test "性格「国士无双」（转世）通过性格门" do
      assert SanwuShou.valid_learn(stats(120, 100, 10), char(800, "国士无双")) == :ok
    end

    test "性格门优先于内力门：性格不合格 + max_neili 不足，仍报性格" do
      assert SanwuShou.valid_learn(stats(200, 200, 10), char(1, "阴险奸诈")) ==
               {:error, "练三无三不手必须要心狠手辣，我看你这点做得还不够。\n"}
    end
  end

  describe "valid_learn/2 学习门槛（LPC max_neili>=800 / force>=120 / whip>=100 / whip>=self）" do
    test "max_neili < 800 被拒（内力不足）" do
      assert SanwuShou.valid_learn(stats(200, 200, 10), char(799)) ==
               {:error, "你的内力不足，没有办法练三无三不手。\n"}
    end

    test "force < 120 被拒（内功火候太浅）" do
      assert SanwuShou.valid_learn(stats(119, 200, 10), char(800)) ==
               {:error, "你的内功火候太浅，没有办法练三无三不手。\n"}
    end

    test "whip < 100 被拒（基本鞭法火候太浅）" do
      assert SanwuShou.valid_learn(stats(200, 99, 10), char(800)) ==
               {:error, "你的基本鞭法火候太浅，没有办法练三无三不手。\n"}
    end

    test "whip < sanwu-shou 被拒（LPC 文案含重复病句，verbatim 保真）" do
      assert SanwuShou.valid_learn(stats(200, 200, 250), char(800)) ==
               {:error, "你的基本鞭法水平有限，无法领会更高深的没有办法练三无三不手。\n"}
    end

    test "全部门槛满足则放行" do
      assert SanwuShou.valid_learn(stats(120, 100, 10), char(800)) == :ok
    end

    test "character 为 nil 时不崩，按「未设天性」被性格门拒" do
      assert SanwuShou.valid_learn(stats(200, 200, 10), nil) ==
               {:error, "练三无三不手必须要心狠手辣，我看你这点做得还不够。\n"}
    end

    test "character 无 meta/vitals 时同样被性格门拒（max_neili 检查跳过）" do
      assert SanwuShou.valid_learn(stats(200, 200, 10), %{}) ==
               {:error, "练三无三不手必须要心狠手辣，我看你这点做得还不够。\n"}
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 60）" do
    test "返回 LPC 一致的消耗" do
      assert SanwuShou.practice_cost() == %{qi: 55, neili: 60}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("sanwu-shou") == SanwuShou
    end
  end
end
