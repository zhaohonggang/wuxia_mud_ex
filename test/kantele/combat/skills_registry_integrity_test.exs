defmodule Kantele.Combat.SkillsRegistryIntegrityTest do
  @moduledoc """
  注册表完整性（覆盖白名单补全 batch1/batch2 新增条目）：

  1. `Skills.all()` 中每个技能模块可加载；
  2. 其 `perform_list/0` 与 `exert_list/0` 路由到的模块均已加载
     （防止注册了「带 performs 但 Perform 模块缺失」的技能，避免 perform 时崩）；
  3. batch2（200 个「有招式+带 performs」特技）确已注册（计数 + 抽样）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills

  test "注册表每个模块可加载，且 perform/exert 路由模块均已加载" do
    for {id, module} <- Skills.all() do
      assert is_atom(module) and Code.ensure_loaded(module) == {:module, module},
             "技能 #{id} 模块未加载：#{inspect(module)}"

      if function_exported?(module, :perform_list, 0) do
        for {name, pmod} <- module.perform_list() do
          assert Code.ensure_loaded(pmod) == {:module, pmod},
                 "#{id} 的 perform #{name} -> #{inspect(pmod)} 未加载"
        end
      end

      if function_exported?(module, :exert_list, 0) do
        for {name, emod} <- module.exert_list() do
          assert Code.ensure_loaded(emod) == {:module, emod},
                 "#{id} 的 exert #{name} -> #{inspect(emod)} 未加载"
        end
      end
    end
  end

  test "白名单补全 batch2/batch3/batch4/batch5 已注册（计数 + 抽样）" do
    # 唯一 id 数 = 既有 255 + batch1 52 + batch2 200 + batch3 105 + batch4 8 + batch5 4 = 624。
    # 注意：@static 里有 12 个既有的「同模块重复 id」（如 huagong-dafa 出现两次，
    # 两次都指向同一模块），Elixir map 按唯一 key 计，故 map_size 为 624 而非 636 行。
    assert map_size(Skills.all()) >= 624

    # batch1 抽样
    for id <- ~w(badao-daofa pixie-sword wudang-zhang qixing-zhi youming-zhi zuiquan-sanda) do
      assert Skills.get(id) != nil, "batch1 #{id} 应已注册"
    end

    # batch2 抽样（有招式 + 带 performs）
    for id <- ~w(bagua-quan shaolin-quan taiji-dao zui-gun songshan-sword taishan-sword) do
      assert Skills.get(id) != nil, "batch2 #{id} 应已注册"
    end

    # batch3 抽样（空招式但非攻击：知识/身法）
    for id <- ~w(literate cooking chess taoism buddhism jinyan-gong tiyunzong shenkong-xing) do
      assert Skills.get(id) != nil, "batch3 #{id} 应已注册"
    end

    # batch4（知识类无招式 + 纯 perform 暗器，共 8 个）
    for id <-
          ~w(idle-force mihun-dafa qimen-wuxing xiaoli-feidao xuanyuan-arrow yufeng-zhen
             yunlong-xinfa zuoyou-hubo) do
      assert Skills.get(id) != nil, "batch4 #{id} 应已注册"
    end

    # batch5（招式表已迁的攻击类特技，共 4 个）
    for id <- ~w(qingyun-bian qixian-wuxingjian tanzhi-shentong yiyang-zhi) do
      assert Skills.get(id) != nil, "batch5 #{id} 应已注册"
    end
  end
end
