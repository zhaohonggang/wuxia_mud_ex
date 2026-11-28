defmodule Kantele.World.InquiryRecruitIntConTest do
  use ExUnit.Case, async: true

  alias Kantele.SectMaster

  # #832 王维扬 wangweiyang.c:149 `query_int() < 35 && query_con() < 35`。
  # 用真实 loader 解析后的 apprentice 配置驱动纯函数门，逐条验证 LPC 语义：
  #   - 「且」门：两项都低才拒；任一达标即放行。
  #   - 派生值：query_int 含 literate/10、query_con 含 force/10。
  #   - 门序：permit 之后、exp / 技能之前（低 int/con + 低 exp 先报 int/con 文案）。
  #   - 零回归：未配置 min_int_con_both 的 NPC 不受影响。

  @deny "你体质孱弱，为人又不机灵，我收下你有什么用？"

  defp gate(overrides \\ %{}) do
    %{
      family: "八卦门",
      permit_recruit: true,
      min_int_con_both: 35,
      int_con_deny: @deny,
      other_family_deny: "不妥，不妥！你已经有师承了。",
      min_exp: 320_000,
      min_exp_deny: "你的江湖经验太差了，我收徒可是件大事，等过段日子再说吧！",
      min_skills: %{"bagua-xinfa" => 100},
      min_skills_deny: %{"bagua-xinfa" => "你本门的内功修为太差了，再回去练练吧。"}
    }
    |> Map.merge(Map.new(overrides))
  end

  defp student(opts) do
    int = Keyword.get(opts, :int, 40)
    con = Keyword.get(opts, :con, 40)
    skills = Keyword.get(opts, :skills, %{"bagua-xinfa" => 120})
    exp = Keyword.get(opts, :exp, 400_000)
    family = Keyword.get(opts, :family, %{})

    %{
      meta: %{
        family: family,
        stats: %{
          int: int,
          con: con,
          skills: skills,
          combat_exp: exp,
          shen: 0
        }
      }
    }
  end

  test "两项同时低于 35 → 拒绝，文案逐字对齐 LPC" do
    assert {:error, reason} = SectMaster.recruit_gate?(nil, student(int: 20, con: 20), gate())
    assert reason == @deny <> "\n"
  end

  test "仅 int 低（con 达标）→ 不被本门拦截，照常收徒" do
    assert :ok = SectMaster.recruit_gate?(nil, student(int: 20, con: 40), gate())
  end

  test "仅 con 低（int 达标）→ 不被本门拦截，照常收徒" do
    assert :ok = SectMaster.recruit_gate?(nil, student(int: 40, con: 20), gate())
  end

  test "两项均达标（含恰好 35）→ 收徒" do
    assert :ok = SectMaster.recruit_gate?(nil, student(int: 35, con: 35), gate())
  end

  test "派生值：literate/10 与 force/10 加成计入 query_int/query_con" do
    # 裸 int=30、con=30 均低于 35，但 literate=80（+8）与 force=80（+8）
    # 把派生值抬到 38 → 两项均达标，LPC query_int()/query_con() 应放行。
    skills = %{"bagua-xinfa" => 120, "literate" => 80, "force" => 80}
    assert :ok = SectMaster.recruit_gate?(nil, student(int: 30, con: 30, skills: skills), gate())
  end

  test "门序：int/con 低于 exp 与技能门 —— 两者同时失败只报 int/con 文案" do
    low_all = student(int: 20, con: 20, exp: 10, skills: %{})

    assert {:error, reason} = SectMaster.recruit_gate?(nil, low_all, gate())
    assert reason =~ "体质孱弱"
    refute reason =~ "经验太差"
    refute reason =~ "内功修为太差"
  end

  test "permit_recruit 先于 int/con：他派玩家先吃他派文案" do
    other = student(int: 20, con: 20, family: %{name: "少林派"})

    assert {:error, reason} = SectMaster.recruit_gate?(nil, other, gate())
    assert reason =~ "已经有师承"
    refute reason =~ "体质孱弱"
  end

  test "UCL 布尔字段未配置（nil）→ 301/低 int/con 玩家照旧走 exp 门，零回归" do
    plain_gate = gate() |> Map.delete(:min_int_con_both)
    low = student(int: 20, con: 20, exp: 10, skills: %{})

    assert {:error, reason} = SectMaster.recruit_gate?(nil, low, plain_gate)
    assert reason =~ "经验太差"
    refute reason =~ "体质孱弱"
  end

  test "deny 文案可被 UCL 覆写（deny_text 约定）" do
    custom = gate(int_con_deny: "资质不合，请回吧")

    assert {:error, reason} = SectMaster.recruit_gate?(nil, student(int: 20, con: 20), custom)
    assert reason == "资质不合，请回吧\n"
  end
end
