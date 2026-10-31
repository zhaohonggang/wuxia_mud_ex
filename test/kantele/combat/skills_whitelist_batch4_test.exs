defmodule Kantele.Combat.SkillsWhitelistBatch4Test do
  @moduledoc """
  白名单补全 batch4（8 个技能）与 LPC 门槛保真。

  这批的「空招式」不是缺口，而是与源一致：

    - 5 个知识类（`idle-force` / `mihun-dafa` / `qimen-wuxing` /
      `yunlong-xinfa` / `zuoyou-hubo`）：源 `type() == "knowledge"`，
      无 `mapping *action`、无 `query_action`，且源里没有 `valid_enable`
      （LPC 调用未定义函数即失败 ⇒ 任何用法都不可 enable）。
    - 3 个暗器（`xiaoli-feidao` / `xuanyuan-arrow` / `yufeng-zhen`）：
      源只有 `perform_action_file`，没有 `query_action`，攻势全走绝招。

  真正补齐的是 `valid_learn/2` 门槛与 `practice_cost/0`：

  1. 注册表登记 + `valid_enable` 用法集合；
  2. `practice_cost`（`nil` = LPC `practice_skill` 返回 `notify_fail` / 未定义）；
  3. 各技能 `valid_learn/2` 的逐条拒绝消息与放行条件；
  4. `@actions == []`（无招式表是有意保真，不是漏迁）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  alias Kantele.Combat.Skills.{
    IdleForce,
    MihunDafa,
    QimenWuxing,
    XiaoliFeidao,
    XuanyuanArrow,
    YufengZhen,
    YunlongXinfa,
    ZuoyouHubo
  }

  @batch4 ~w(idle-force mihun-dafa qimen-wuxing xiaoli-feidao xuanyuan-arrow yufeng-zhen
             yunlong-xinfa zuoyou-hubo)

  @knowledge ~w(idle-force mihun-dafa qimen-wuxing yunlong-xinfa zuoyou-hubo)

  @throwing %{
    "xiaoli-feidao" => XiaoliFeidao,
    "xuanyuan-arrow" => XuanyuanArrow,
    "yufeng-zhen" => YufengZhen
  }

  @learn_only ~w(idle-force mihun-dafa qimen-wuxing yunlong-xinfa zuoyou-hubo)

  defp stats(skills, extra \\ %{}) do
    Map.merge(%{skills: skills}, extra)
  end

  defp char(max_neili), do: %{meta: %{vitals: %{max_neili: max_neili}}}

  # yufeng-zhen 的 query_dex() 需要真 %Stats{} 结构体
  defp dex_stats(force, dodge, yufeng, dex) do
    %Stats{
      dex: dex,
      skills: %{"force" => force, "dodge" => dodge, "throwing" => 200, "yufeng-zhen" => yufeng}
    }
  end

  defp hubo_stats(force, lvl, count \\ 0, int \\ 10) do
    %{int: int, skills: %{"force" => force, "zuoyou-hubo" => lvl, "count" => count}}
  end

  defp male, do: %{meta: %{env: %{gender: "男性"}}, attributes: %{}}
  defp neuter, do: %{meta: %{env: %{gender: "无性"}}, attributes: %{}}

  defp with_special(id),
    do: %{meta: %{env: %{gender: "男性"}}, attributes: %{"special_skills" => %{id => true}}}

  describe "注册表" do
    test "batch4 全部 8 个已注册" do
      for id <- @batch4 do
        assert Skills.get(id) != nil, "batch4 #{id} 应已注册"
      end
    end

    test "知识类：任何用法都不可 enable，且无招式表" do
      for id <- @knowledge do
        module = Skills.get(id)

        for usage <- ~w(unarmed sword blade staff club whip stick dagger
                        throwing finger hand claw strike cuff force parry dodge) do
          refute module.valid_enable(usage), "#{id} 不应 enable 到 #{usage}"
        end

        assert module.actions() == [], "#{id} 源无招式表，@actions 应为空"
      end
    end

    test "暗器：只可 enable 到 throwing，且无招式表" do
      for {id, module} <- @throwing do
        assert module.valid_enable("throwing"), "#{id} 应可 enable 到 throwing"

        for usage <- ~w(unarmed sword blade force parry dodge) do
          refute module.valid_enable(usage), "#{id} 不应 enable 到 #{usage}"
        end

        assert module.actions() == [], "#{id} 源无 query_action，@actions 应为空"
        assert module.query_action(200) == %{}, "#{id} 无招式时应回落 %{}"
      end
    end
  end

  describe "practice_cost" do
    test "知识类只能学不能练（nil）" do
      for id <- @learn_only do
        assert Skills.get(id).practice_cost() == nil, "#{id} 应为 practice_cost nil"
      end
    end

    test "暗器沿用 LPC practice_skill 的扣减" do
      assert XiaoliFeidao.practice_cost() == %{qi: 35, neili: 48}
      assert XuanyuanArrow.practice_cost() == %{qi: 70, neili: 0}
      assert YufengZhen.practice_cost() == %{qi: 52, neili: 35}
    end
  end

  describe "xiaoli-feidao valid_learn/2" do
    test "max_neili < 1500 被拒" do
      assert XiaoliFeidao.valid_learn(
               stats(%{"force" => 200, "throwing" => 200, "xiaoli-feidao" => 100}),
               char(1499)
             ) == {:error, "你的内力不够，没有办法练小李飞刀。\n"}
    end

    test "force < 200 被拒" do
      assert XiaoliFeidao.valid_learn(
               stats(%{"force" => 199, "throwing" => 200, "xiaoli-feidao" => 100}),
               char(1500)
             ) == {:error, "你的内功火候不够，没有办法练小李飞刀。\n"}
    end

    test "throwing < 本门等级被拒" do
      assert XiaoliFeidao.valid_learn(
               stats(%{"force" => 200, "throwing" => 99, "xiaoli-feidao" => 100}),
               char(1500)
             ) == {:error, "你的基本暗器水平有限，无法领会更高深的小李飞刀。\n"}
    end

    test "三项满足则放行" do
      assert XiaoliFeidao.valid_learn(
               stats(%{"force" => 200, "throwing" => 100, "xiaoli-feidao" => 100}),
               char(1500)
             ) == :ok
    end

    test "character 无 vitals 时跳过 max_neili 检查（与既有迁移一致）" do
      assert XiaoliFeidao.valid_learn(
               stats(%{"force" => 200, "throwing" => 100, "xiaoli-feidao" => 100}),
               %{}
             ) == :ok
    end
  end

  describe "xuanyuan-arrow valid_learn/2" do
    test "throwing < 20 被拒" do
      assert XuanyuanArrow.valid_learn(stats(%{"throwing" => 19}), %{}) ==
               {:error, "你的暗器技能不够娴熟，怎能在激战中上箭开弓射敌？\n"}
    end

    test "throwing >= 20 放行" do
      assert XuanyuanArrow.valid_learn(stats(%{"throwing" => 20}), %{}) == :ok
    end

    test "源 query_skill(\"xuanyuan-arror\") 拼写错误导致第二条判定恒假（保真不生效）" do
      # 源：throwing < query_skill("xuanyuan-arror", 1) —— 该技能不存在，恒取 0。
      assert XuanyuanArrow.valid_learn(stats(%{"throwing" => 20, "xuanyuan-arrow" => 999}), %{}) ==
               :ok
    end
  end

  describe "yufeng-zhen valid_learn/2" do
    test "force < 60 被拒" do
      assert YufengZhen.valid_learn(dex_stats(59, 200, 100, 40), %{}) ==
               {:error, "你的内功心法火候不够，无法学玉蜂针。\n"}
    end

    test "dodge < 80 被拒" do
      assert YufengZhen.valid_learn(dex_stats(60, 79, 100, 40), %{}) ==
               {:error, "你的轻功火候不够，无法领悟玉蜂针。\n"}
    end

    test "query_dex() < 26 被拒（派生身法含 dodge/10）" do
      # base dex 10 + dodge 80/10 = 18 < 26
      assert YufengZhen.valid_learn(dex_stats(60, 80, 100, 10), %{}) ==
               {:error, "你的身法不够灵巧，无法领悟玉蜂针。\n"}
    end

    test "throwing < 本门等级被拒" do
      # base dex 20 + 80/10 = 28 已过身法门，此处再撞 throwing 门
      assert YufengZhen.valid_learn(dex_stats(60, 80, 201, 20), %{}) ==
               {:error, "你的基本暗器水平有限，难以领会更高深的玉蜂针。\n"}
    end

    test "四项满足则放行" do
      assert YufengZhen.valid_learn(dex_stats(60, 80, 100, 20), %{}) == :ok
    end
  end

  describe "qimen-wuxing valid_learn/2" do
    test "mathematics < 200 被拒" do
      assert QimenWuxing.valid_learn(stats(%{"mathematics" => 199}), %{}) ==
               {:error, "你的算术知识太差，无法理解奇门五行的奥妙。\n"}
    end

    test "mathematics < qimen-wuxing 被拒" do
      assert QimenWuxing.valid_learn(
               stats(%{"mathematics" => 200, "qimen-wuxing" => 201}),
               %{}
             ) == {:error, "你的算术知识有限，无法理解更深奥的奇门五行。\n"}
    end

    test "算术不弱于本门则放行" do
      assert QimenWuxing.valid_learn(stats(%{"mathematics" => 200, "qimen-wuxing" => 200}), %{}) ==
               :ok
    end
  end

  describe "zuoyou-hubo valid_learn/2" do
    test "无性且等级 >= 50 被拒" do
      assert ZuoyouHubo.valid_learn(hubo_stats(200, 50), neuter()) ==
               {:error, "你默默凝神，试图分心二用，可是却觉得阴阳失调，心浮气躁。\n"}
    end

    test "无性但等级 < 50 放行" do
      assert ZuoyouHubo.valid_learn(hubo_stats(200, 49), neuter()) == :ok
    end

    test "已通算术（count > 0）被拒" do
      assert ZuoyouHubo.valid_learn(hubo_stats(200, 10, 1), male()) ==
               {:error, "你受到阴阳八卦影响甚深，难以尝试更高深的分心之术。\n"}
    end

    test "拥有 special_skill/qinzong 被拒" do
      assert ZuoyouHubo.valid_learn(hubo_stats(200, 10), with_special("qinzong")) ==
               {:error, "你受到阴阳八卦影响甚深，难以尝试更高深的分心之术。\n"}
    end

    test "悟性 > 15 且无 tiandao 被拒" do
      assert ZuoyouHubo.valid_learn(hubo_stats(200, 10, 0, 16), male()) ==
               {:error, "你觉得心烦意乱，难以尝试更高深的分心之术。\n"}
    end

    test "悟性 > 15 但拥有 special_skill/tiandao 则过此门" do
      assert ZuoyouHubo.valid_learn(hubo_stats(200, 10, 0, 16), with_special("tiandao")) == :ok
    end

    test "force < lvl * 3 / 4 被拒（C 整数除法）" do
      # lvl 100 -> 需要 force >= 75
      assert ZuoyouHubo.valid_learn(hubo_stats(74, 100), male()) ==
               {:error, "你的内功火候不够，难以轻松自如的分运两股内力。\n"}

      assert ZuoyouHubo.valid_learn(hubo_stats(75, 100), male()) == :ok
    end

    test "LPC 整数除法截断：lvl 3 -> 需要 force >= 2" do
      # 3 * 3 / 4 = 2（不是 2.25）
      assert ZuoyouHubo.valid_learn(hubo_stats(1, 3), male()) ==
               {:error, "你的内功火候不够，难以轻松自如的分运两股内力。\n"}

      assert ZuoyouHubo.valid_learn(hubo_stats(2, 3), male()) == :ok
    end
  end

  describe "yunlong-xinfa / idle-force / mihun-dafa" do
    test "valid_learn 沿用基类默认放行" do
      for module <- [YunlongXinfa, IdleForce, MihunDafa] do
        assert module.valid_learn(stats(%{}), %{}) == :ok
      end
    end
  end
end
