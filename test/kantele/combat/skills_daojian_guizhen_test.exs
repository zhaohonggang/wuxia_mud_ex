defmodule Kantele.Combat.SkillsDaojianGuizhenTest do
  @moduledoc """
  刀剑归真学习门槛迁移（C 相位，daojian-guizhen 真缺口补齐）。

  对照 `kungfu/skill/daojian-guizhen.c`：
  - valid_learn: 性格须「光明磊落」或「国士无双」/ int>=35 / dex>=25 / martial-cognize>=250 /
    max_neili>=4500 / sword>=250 且 blade>=250 / 「刀剑均低于本技能」/「其一低于本技能」；
  - 性格门读 `meta.character`（LPC `query("character")`）；LPC 未设时为 0，既不是
    「光明磊落」也不是「国士无双」→ **拒**（源里唯一的赋値点是 `adm/daemons/updated.c:515`
    转世设「国士无双」，故本技能实为转世专属）；
  - LPC 末门允许 `ultrap` 且刀剑均>=320 时只需其一达标，本仓无 ultrap 判定 → 按非大宗师处理；
  - practice_skill 扣 qi 85 / neili 85。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DaojianGuizhen

  defp stats(int, dex, cognize, sword, blade, self_lvl) do
    %{
      int: int,
      dex: dex,
      skills: %{
        "martial-cognize" => cognize,
        "sword" => sword,
        "blade" => blade,
        "daojian-guizhen" => self_lvl
      }
    }
  end

  # 默认给通过性格门的「光明磊落」
  defp char(mn, personality \\ "光明磊落"),
    do: %{meta: %{vitals: %{max_neili: mn}, character: personality}}

  # 默认全达标：int 40 / dex 30 / cognize 300 / sword 300 / blade 300 / self 10
  defp ok_stats, do: stats(40, 30, 300, 300, 300, 10)

  describe "valid_learn/2 性格门（LPC query(\"character\") 须光明磊落或国士无双）" do
    test "性格为「心狠手辣」被拒（性格门在 int 门之前）" do
      assert DaojianGuizhen.valid_learn(ok_stats(), char(5000, "心狠手辣")) ==
               {:error, "你练习了半天，心中暗道：什么刀剑合一，竟如此难练，这东西不练也罢。\n"}
    end

    test "性格未设（nil）按 LPC「未设即 0」拒" do
      assert DaojianGuizhen.valid_learn(ok_stats(), char(5000, nil)) ==
               {:error, "你练习了半天，心中暗道：什么刀剑合一，竟如此难练，这东西不练也罢。\n"}
    end

    test "性格「国士无双」（转世）通过性格门" do
      assert DaojianGuizhen.valid_learn(ok_stats(), char(5000, "国士无双")) == :ok
    end

    test "性格门优先于 int 门：性格不合格 + int 不足，仍报性格" do
      assert DaojianGuizhen.valid_learn(stats(10, 30, 300, 300, 300, 10), char(5000, "阴险奸诈")) ==
               {:error, "你练习了半天，心中暗道：什么刀剑合一，竟如此难练，这东西不练也罢。\n"}
    end
  end

  describe "valid_learn/2 学习门槛" do
    test "int < 35 被拒（天资不足）" do
      assert DaojianGuizhen.valid_learn(stats(34, 30, 300, 300, 300, 10), char(5000)) ==
               {:error, "你研究了半天，却只感剑法和刀法毫无牵连，看来是自己天资不足。\n"}
    end

    test "dex < 25 被拒（身法灵动性不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 24, 300, 300, 300, 10), char(5000)) ==
               {:error, "你研究了半天，只觉依自己的身法灵动性，根本无法修习这门武功。\n"}
    end

    test "martial-cognize < 250 被拒（武学修养不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 249, 300, 300, 10), char(5000)) ==
               {:error, "你觉得苗家剑法和胡家刀法都极其深奥，依照自己武学修养难以理解。\n"}
    end

    test "max_neili < 4500 被拒（内力太弱）" do
      assert DaojianGuizhen.valid_learn(ok_stats(), char(4499)) ==
               {:error, "你的内力太弱，无法将苗家剑法和胡家刀法二者合一学习。\n"}
    end

    test "sword < 250 被拒（刀剑根基火候不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 249, 300, 10), char(5000)) ==
               {:error, "你的刀剑根基火候不足，难以修炼刀剑归真。\n"}
    end

    test "blade < 250 被拒（刀剑根基火候不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 300, 249, 10), char(5000)) ==
               {:error, "你的刀剑根基火候不足，难以修炼刀剑归真。\n"}
    end

    test "刀剑均低于本技能被拒（刀剑根基火候不足，无法领会）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 260, 260, 400), char(5000)) ==
               {:error, "你的刀剑根基火候不足，无法领会更高深的刀剑归真。\n"}
    end

    test "仅其一低于本技能被拒（刀法或剑法火候不足；ultrap 未建模按非大宗师处理）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 400, 260, 400), char(5000)) ==
               {:error, "你的刀法或剑法火候不足，无法领会更高深的刀剑归真。\n"}
    end

    test "刀剑均不低于本技能则放行" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 400, 400, 400), char(5000)) == :ok
    end

    test "character 为 nil 时不崩，按「未设天性」被性格门拒" do
      assert DaojianGuizhen.valid_learn(ok_stats(), nil) ==
               {:error, "你练习了半天，心中暗道：什么刀剑合一，竟如此难练，这东西不练也罢。\n"}
    end

    test "character 无 meta/vitals 时同样被性格门拒（max_neili 检查跳过）" do
      assert DaojianGuizhen.valid_learn(ok_stats(), %{}) ==
               {:error, "你练习了半天，心中暗道：什么刀剑合一，竟如此难练，这东西不练也罢。\n"}
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 85 / neili 85）" do
    test "返回 LPC 一致的消耗" do
      assert DaojianGuizhen.practice_cost() == %{qi: 85, neili: 85}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("daojian-guizhen") == DaojianGuizhen
    end
  end
end
