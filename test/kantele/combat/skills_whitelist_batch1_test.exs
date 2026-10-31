defmodule Kantele.Combat.SkillsWhitelistBatch1Test do
  @moduledoc """
  白名单补全 batch1：52 个「有静态招式、无 performs、无自定义门槛」的门派特技注册校验。

  这些技能此前被 data/world/*.ucl 引用（NPC 可教）却不在 @static → Skills.get=nil 不可学。
  本批仅补白名单；招式（@actions）已在翻译阶段生成，故注册后战斗可用。
  学习仍受教习流程（门派/等级/潜能）门控；未注册时玩家只会看到「没有这项武功」。

  刻意排除（本批不含）：
  - 引擎基础用法（dodge/parry/sword/unarmed/blade/...，由引擎按 usage 管理，不注册）；
  - 空 @actions 的攻击特技（需先补招式，否则「能学能 map、出手无招」）；
  - 带 performs/exerts 的特技（需先核对 Perform 模块存在，另批处理）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills

  @batch1 ~w(
    badao-daofa cha-quan changquan chongling-jian da-qinna datianlong-zhi emei-jiuyang
    feilong-shou fuhu-quan hengshan-jian hengshan-sword hongjian-yulu huashan-quanfa
    huashan-zhangfa jiaohua-bangfa juemen-gun lianhua-zhi liuhe-quan liuxing-chui
    paiyun-shou piaomiao-zhang pixie-sword pona-gong qianlong-wuyong qilian-zhi
    qingmang-zhang qinna-shibada qixing-gun qixing-zhi shaolin-jiuyang shaolin-quan
    shaolin-tantui shenfeng-bian shenlong-baiwei shennong-zhang siji-jianfa
    songfeng-jian songshan-sword suoming-zhang taiji-dao taishan-sword tianzhu-fuzhi
    wudang-jiuyang wudang-zhang xiao-qinna yanqing-quan yipai-liangsan youming-zhi
    yunlong-shou yunlong-zhua zhenjing-baili zuiquan-sanda
  )

  # 覆盖本批实际出现的用法（含九阳三系的 force），并留出常见攻击/身法用法。
  @usages ~w(sword blade staff stick club spear whip hammer axe dagger knife
             lance throwing unarmed strike cuff finger claw hand leg dodge move parry force)

  test "52 个特技均已注册、模块可加载、且有静态招式" do
    assert length(@batch1) == 52

    for id <- @batch1 do
      module = Skills.get(id)

      assert is_atom(module) and Code.ensure_loaded(module) == {:module, module},
             "#{id} 应已注册且模块可加载"

      assert module.actions() != [], "#{id} 应有静态招式（非空 @actions）"

      assert Enum.any?(@usages, &module.valid_enable/1),
             "#{id} 应至少启用一种攻击/内功用法"
    end
  end
end
