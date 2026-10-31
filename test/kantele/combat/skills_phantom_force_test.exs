defmodule Kantele.Combat.SkillsPhantomForceTest do
  @moduledoc """
  F4 相位：37 个 phantom 内功空壳（本仓迁 36 + 早前已迁 longxiang-gong）的
  注册与基础契约校验。

  覆盖：
  - 全部 36 门空壳已注册进 Skills.@static（Skills.get 非 nil、模块已加载）；
  - valid_enable("force") 为真（它们都是内功）；
  - practice_cost() == nil（LPC practice_skill 返回失败 → 只能学不能练）；
  - valid_force 白名单往返（接受白名单内、拒绝白名单外）；
  - 6 个 RICH 空壳的 valid_learn/2 学习门槛（与 LPC 保真）。

  真缺口定位：这些内功被 data/world/*.ucl / clone_lib.ucl 引用（NPC 可能传授），
  但原本不在 Skills.@static，导致 Skills.get 返回 nil、不可学。现全部保真迁移并注册。

  已知刻意偏差（引擎未建模层）已注释在各自 .ex 源码中：
  - hamagong/xiantian-gong：攻击方 neili 自耗 -30、prepared 门控未迁移；
  - hamagong/xiantian-gong/xuedao-dafa：query("character") 性格门槛（meta.character 恒 nil）跳过；
  - xuedao-dafa：hit_ob 二次出招机制未建模，引擎 function_exported? 守卫安全回退 {0, nil, []}。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills

  # id => 该内功 valid_force 白名单（与各自 .ex 源码一致）
  @force_skills [
    {"bagua-xinfa", ["nei-bagua", "bagua-xinfa", "shangjia-neigong"]},
    {"baituo-xinfa", ["hamagong"]},
    {"emei-xinfa", ["wudang-xinfa", "linji-zhuang", "taiji-shengong"]},
    {"guixi-gong", ["huagong-dafa", "freezing-force"]},
    {"henshan-xinfa", ["huashan-xinfa", "zixia-shengong", "songshan-xinfa", "hanbing-zhenqi", "zhenyue-jue"]},
    {"honghua-xinfa", ["yijinjing", "taiji-shengong", "tianchi-neigong", "zhanshen-xinjing"]},
    {"huashan-xinfa", ["henshan-xinfa", "zixia-shengong", "songshan-xinfa", "hanbing-zhenqi", "zhenyue-jue"]},
    {"jiaohua-neigong", ["huntian-qigong"]},
    {"jueqing-xinfa", ["tianlei-shengong", "tiezhang-xinfa", "fenxin-jue"]},
    {"kunlun-xinfa", ["kunlun-xinfa", "liangyi-shengong"]},
    {"lingjiu-xinfa", ["bahuang-gong", "xiaoyao-xinfa", "beiming-shengong", "xiaowuxiang"]},
    {"luoying-xinfa", ["bibo-shengong"]},
    {"minggu-xinfa", ["xuanming-shengong"]},
    {"mizong-neigong", ["longxiang-gong", "xiaowuxiang", "xuedao-dafa"]},
    {"murong-xinfa", ["zihui-xinfa"]},
    {"qingcheng-neigong", ["qingcheng-neigong", "changqing-shengong"]},
    {"quanzhen-xinfa", ["xiantian-gong", "suxin-jue", "yunv-xinjing", "duanshi-xinfa", "kurong-changong", "xuanmen-neigong"]},
    {"riyue-xinfa", ["tianhuan-shenjue", "xuantian-wujigong", "wuzheng-xinfa"]},
    {"shangjia-neigong", ["shangjia-neigong", "bagua-xinfa", "nei-bagua"]},
    {"shaolin-xinfa", ["yijinjing", "taiji-shengong", "wudang-xinfa", "hunyuan-yiqi"]},
    {"songshan-xinfa", ["huashan-xinfa", "henshan-xinfa", "zixia-shengong", "hanbing-zhenqi", "zhenyue-jue"]},
    {"suxin-jue", ["yunv-xinjing", "xuanmen-neigong", "xiantian-gong", "quanzhen-xinfa"]},
    {"tiezhang-xinfa", ["tianlei-shengong", "jueqing-xinfa", "fenxin-jue"]},
    {"wudang-xinfa", ["yijinjing", "taiji-shengong", "linji-zhuang", "emei-xinfa", "shaolin-xinfa", "hunyuan-yiqi"]},
    {"wudu-xinfa", ["hamagong", "xiuluo-yinshagong", "shunxi-qianli"]},
    {"wuliang-xinfa", ["dahai-wuliang", "lingjiu-xinfa", "bahuang-gong", "wudoumi-shengong"]},
    {"wuzheng-xinfa", ["tianhuan-shenjue", "xuantian-wujigong", "riyue-xinfa"]},
    {"xiaoyao-xinfa", ["beiming-shengong", "lingjiu-xinfa", "bahuang-gong", "xiaowuxiang"]},
    {"xueshan-neigong", ["xueshan-neigong", "wuwang-shengong"]},
    {"yaogu-xinfa", ["shennong-xinjing", "yaogu-xinfa", "lengyue-shengong", "hujia-neigong", "danyang-tunafa", "miaojia-neigong"]},
    {"hamagong", ["baituo-xinfa"]},
    {"xiantian-gong", ["quanzhen-xinfa", "duanshi-xinfa", "suxin-jue", "yunv-xinjing", "kurong-changong", "xuanmen-neigong"]},
    {"xuedao-dafa", ["longxiang-gong", "xiaowuxiang", "mizong-neigong"]},
    {"shennong-xinjing", ["shennong-xinjing", "yaogu-xinfa", "lengyue-shengong", "hujia-neigong", "danyang-tunafa", "miaojia-neigong"]},
    {"tianchi-neigong", ["zhanshen-xinjing", "honghua-xinfa"]},
    {"yunv-xinfa", ["suxin-jue", "quanzhen-xinfa"]}
  ]

  defp mod(id), do: Skills.get(id)

  defp male_char(mn \\ 9999), do: %{meta: %{vitals: %{max_neili: mn}, env: %{gender: "男性"}}}
  defp none_char(mn \\ 9999), do: %{meta: %{vitals: %{max_neili: mn}, env: %{gender: "无性"}}}

  # 基础属性默认 50（达门槛）、各相关技能默认 300（达门槛），按需覆盖。
  defp stats(attrs) do
    base = %{
      str: 50,
      int: 50,
      dex: 50,
      con: 50,
      skills: %{
        "force" => 300,
        "strike" => 300,
        "poison" => 300,
        "blade" => 300,
        "unarmed" => 300,
        "taoism" => 400
      }
    }

    %{
      base
      | str: Map.get(attrs, :str, base.str),
        int: Map.get(attrs, :int, base.int),
        dex: Map.get(attrs, :dex, base.dex),
        con: Map.get(attrs, :con, base.con),
        skills: Map.merge(base.skills, Map.get(attrs, :skills, %{}))
    }
  end

  describe "注册与基础契约（36 门内功空壳）" do
    test "全部已注册 Skills.@static 且 force 可用、只能学(learn)不能练(practice)" do
      assert length(@force_skills) == 36

      for {id, valid_forces} <- @force_skills do
        module = Skills.get(id)

        assert is_atom(module) and Code.ensure_loaded(module) == {:module, module},
               "Skills.get(#{inspect(id)}) 应返回已加载的武学模块"

        assert module.valid_enable("force"), "#{id} 应 enable force"
        assert module.practice_cost() == nil, "#{id} 应只能学(learn)不能练(practice)"

        for f <- valid_forces do
          assert module.valid_force(f), "#{id} 应接受 valid_force #{f}"
        end

        refute module.valid_force("zzz-no-such-force-zzz"), "#{id} 应拒绝无效 force"
      end
    end
  end

  describe "hamagong valid_learn/2 门槛（LPC 保真）" do
    test "valid_enable 含 force/parry/strike，不含 blade/sword" do
      m = mod("hamagong")
      assert m.valid_enable("force")
      assert m.valid_enable("parry")
      assert m.valid_enable("strike")
      refute m.valid_enable("blade")
      refute m.valid_enable("sword")
    end

    test "四项基础属性与技能门槛全满足则放行" do
      assert mod("hamagong").valid_learn(
               stats(%{str: 50, con: 50, skills: %{"force" => 300, "strike" => 300, "poison" => 300}}),
               male_char()
             ) == :ok
    end

    test "str < 32 被拒" do
      assert mod("hamagong").valid_learn(stats(%{str: 20}), male_char()) ==
               {:error, "你先天臂力孱弱，无法修炼蛤蟆功。\n"}
    end

    test "con < 32 被拒" do
      assert mod("hamagong").valid_learn(stats(%{con: 20}), male_char()) ==
               {:error, "你先天根骨太差，无法修炼蛤蟆功。\n"}
    end

    test "无性且自身等级 > 49 被拒" do
      assert mod("hamagong").valid_learn(
               stats(%{skills: %{"hamagong" => 50, "force" => 300, "strike" => 300, "poison" => 300}}),
               none_char()
             ) == {:error, "你无根无性，阴阳不调，难以领会高深的蛤蟆功。\n"}
    end

    test "force < 50 被拒" do
      assert mod("hamagong").valid_learn(
               stats(%{skills: %{"force" => 10, "strike" => 300, "poison" => 300}}),
               male_char()
             ) == {:error, "你的基本内功火候不足，不能学蛤蟆功。\n"}
    end

    test "strike < 150 被拒" do
      assert mod("hamagong").valid_learn(
               stats(%{skills: %{"force" => 300, "strike" => 10, "poison" => 300}}),
               male_char()
             ) == {:error, "你的基本掌法火候不足，难以领会蛤蟆功。\n"}
    end

    test "poison < 150 被拒" do
      assert mod("hamagong").valid_learn(
               stats(%{skills: %{"force" => 300, "strike" => 300, "poison" => 10}}),
               male_char()
             ) == {:error, "你的基本毒技火候不足，难以领会蛤蟆功。\n"}
    end

    test "max_neili < 2500 被拒" do
      assert mod("hamagong").valid_learn(
               stats(%{skills: %{"force" => 300, "strike" => 300, "poison" => 300}}),
               male_char(1000)
             ) == {:error, "你现在的内力修为不足，难以领会蛤蟆功。\n"}
    end
  end

  describe "xiantian-gong valid_learn/2 门槛（LPC 保真）" do
    test "valid_enable 含 force/parry/unarmed，不含 blade/sword" do
      m = mod("xiantian-gong")
      assert m.valid_enable("force")
      assert m.valid_enable("parry")
      assert m.valid_enable("unarmed")
      refute m.valid_enable("blade")
      refute m.valid_enable("sword")
    end

    test "全满足则放行" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{int: 50, con: 50, skills: %{"force" => 300, "unarmed" => 300, "taoism" => 400}}),
               male_char()
             ) == :ok
    end

    test "int < 34 被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{int: 20, skills: %{"force" => 300, "unarmed" => 300, "taoism" => 400}}),
               male_char()
             ) == {:error, "你的先天悟性不足，难以领会高深的先天功。\n"}
    end

    test "con < 34 被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{con: 20, skills: %{"force" => 300, "unarmed" => 300, "taoism" => 400}}),
               male_char()
             ) == {:error, "你的先天根骨孱弱，无法修炼高深的先天功。\n"}
    end

    test "非男性被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{int: 50, con: 50, skills: %{"force" => 300, "unarmed" => 300, "taoism" => 400}}),
               none_char()
             ) == {:error, "先天功乃是纯阳玄功，只有男子方可修习。\n"}
    end

    test "taoism < 200 被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{skills: %{"force" => 300, "unarmed" => 300, "taoism" => 100}}),
               male_char()
             ) == {:error, "你对道学心法的理解不够，难以领会先天功。\n"}
    end

    test "force < 200 被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{skills: %{"force" => 100, "unarmed" => 300, "taoism" => 400}}),
               male_char()
             ) == {:error, "你的基本内功火候不足，难以领会先天功。\n"}
    end

    test "unarmed < 200 被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{skills: %{"force" => 300, "unarmed" => 100, "taoism" => 400}}),
               male_char()
             ) == {:error, "你的基本拳脚火候不足，难以领会先天功。\n"}
    end

    test "max_neili < 3500 被拒" do
      assert mod("xiantian-gong").valid_learn(
               stats(%{skills: %{"force" => 300, "unarmed" => 300, "taoism" => 400}}),
               male_char(1000)
             ) == {:error, "你的内力修为不足，难以领会先天功。\n"}
    end
  end

  describe "xuedao-dafa valid_learn/2 门槛（LPC 保真）" do
    test "valid_enable 含 blade/force/parry，不含 sword/unarmed" do
      m = mod("xuedao-dafa")
      assert m.valid_enable("blade")
      assert m.valid_enable("force")
      assert m.valid_enable("parry")
      refute m.valid_enable("sword")
      refute m.valid_enable("unarmed")
    end

    test "全满足则放行" do
      assert mod("xuedao-dafa").valid_learn(
               stats(%{str: 50, dex: 50, skills: %{"force" => 300, "blade" => 300}}),
               male_char()
             ) == :ok
    end

    test "str < 28 被拒" do
      assert mod("xuedao-dafa").valid_learn(
               stats(%{str: 10, skills: %{"force" => 300, "blade" => 300}}),
               male_char()
             ) == {:error, "你先天膂力孱弱，无法修炼血刀大法。\n"}
    end

    test "dex < 26 被拒" do
      assert mod("xuedao-dafa").valid_learn(
               stats(%{dex: 10, skills: %{"force" => 300, "blade" => 300}}),
               male_char()
             ) == {:error, "你先天身法太差，无法修炼血刀大法。\n"}
    end

    test "无性且自身等级 > 29 被拒" do
      assert mod("xuedao-dafa").valid_learn(
               stats(%{skills: %{"xuedao-dafa" => 30, "force" => 300, "blade" => 300}}),
               none_char()
             ) == {:error, "你无根无性，阴阳不调，难以领会高深的血刀大法。\n"}
    end

    test "force < 120 被拒" do
      assert mod("xuedao-dafa").valid_learn(
               stats(%{skills: %{"force" => 10, "blade" => 300}}),
               male_char()
             ) == {:error, "你的基本内功火候不足，不能学血刀大法。\n"}
    end

    test "max_neili < 1600 被拒" do
      assert mod("xuedao-dafa").valid_learn(
               stats(%{skills: %{"force" => 300, "blade" => 300}}),
               male_char(1000)
             ) == {:error, "你的内力修为不足，不能学血刀大法。\n"}
    end
  end

  describe "shennong-xinjing valid_learn/2 门槛（LPC 保真）" do
    test "全满足则放行" do
      assert mod("shennong-xinjing").valid_learn(stats(%{skills: %{"force" => 100}}), male_char()) == :ok
    end

    test "无性且自身等级 > 99 被拒" do
      assert mod("shennong-xinjing").valid_learn(
               stats(%{skills: %{"shennong-xinjing" => 100, "force" => 100}}),
               none_char()
             ) == {:error, "你无根无性，阴阳不调，难以领会高深的神农心经。\n"}
    end

    test "force < 60 被拒" do
      assert mod("shennong-xinjing").valid_learn(stats(%{skills: %{"force" => 10}}), male_char()) ==
               {:error, "你的基本内功火候还不够。\n"}
    end
  end

  describe "tianchi-neigong valid_learn/2 门槛（LPC 保真）" do
    test "全满足则放行" do
      assert mod("tianchi-neigong").valid_learn(stats(%{skills: %{"force" => 100}}), male_char()) == :ok
    end

    test "force < 60 被拒" do
      assert mod("tianchi-neigong").valid_learn(stats(%{skills: %{"force" => 10}}), male_char()) ==
               {:error, "你的基本内功火候还不够。\n"}
    end

    test "无性且自身等级 > 49 被拒" do
      assert mod("tianchi-neigong").valid_learn(
               stats(%{skills: %{"tianchi-neigong" => 50, "force" => 100}}),
               none_char()
             ) == {:error, "你无根无性，阴阳不调，难以领会高深的天池内功。\n"}
    end
  end

  describe "yunv-xinfa valid_learn/2 门槛（LPC 保真）" do
    test "全满足则放行" do
      assert mod("yunv-xinfa").valid_learn(stats(%{int: 50, skills: %{"force" => 300}}), male_char()) == :ok
    end

    test "无性被拒" do
      assert mod("yunv-xinfa").valid_learn(stats(%{int: 50, skills: %{"force" => 300}}), none_char()) ==
               {:error, "你无根无性，阴阳难调，不能修习玉女心经。\n"}
    end

    test "force < 150 被拒" do
      assert mod("yunv-xinfa").valid_learn(stats(%{int: 50, skills: %{"force" => 10}}), male_char()) ==
               {:error, "你的基本内功火候还不够，不能修习玉女心经。\n"}
    end

    test "int < 32 被拒" do
      assert mod("yunv-xinfa").valid_learn(stats(%{int: 10, skills: %{"force" => 300}}), male_char()) ==
               {:error, "你的先天悟性不足，无法领悟玉女心经。\n"}
    end

    test "max_neili < 2000 被拒" do
      assert mod("yunv-xinfa").valid_learn(stats(%{int: 50, skills: %{"force" => 300}}), male_char(1000)) ==
               {:error, "你的内力修为不足，难以领会玉女心经。\n"}
    end
  end
end
