defmodule Kantele.Combat.SkillsValidLearnBatch2Test do
  @moduledoc """
  `valid_learn/2` 补全 wave2：持械门基础设施 + 178 个技能。

  wave1（116 个）之后剩下 206 个里，**177 个**卡在 `me->query_temp("weapon")`：
  teach 事件切片（`skills_event.ex`）只带 `vitals/env/spouse`，师父进程看不到学生
  的装备，所以「必须空手 / 必须持某类兵器」的门无法判定。

  本批先补基础设施：

    - `LearnCommand` 随 `skills/learn` 事件带 `student_equipped`
      （`character.meta.combat.equipped`），`room.ex` 原样转发给 `skills/teach`，
      师父侧组装成 `meta.combat.equipped` 的切片。
    - `Kantele.Combat.Skill` 新增三个判定器：
      `wielding?/1`（`query_temp("weapon")`）、`secondary_wielding?/1`
      （`query_temp("secondary_weapon")`）、`wielded_skill_type/1`
      （`weapon->query("skill_type")`）。三者同时接受完整 Character 与切片。

  生成器据此把 244 处持械条件折成这三类，并按源顺序落成 `cond`。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SkillsEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skill
  alias Kantele.Combat.Skills

  @generated ~w(
    bagua-quan bagua-zhang baihua-cuoquan baihua-quan baisheng-quan bazhen-zhang
    benlei-zhang biluo-zhang canglang-zhi canhe-zhi cha-quan changquan chansi-shou
    chilian-shenzhang chongling-jian chongtian-zhang chongyang-shenzhang chuncan-zhang
    da-qinna dabei-zhang dacidabei-shou dashou-yin datianlong-zhi dispel-poison
    dulong-shenzhua feifeng-bian feihua-zhang feilong-shou fuhu-quan guanchong-sword
    guhong-zhang guzhuo-zhang haotian-zhang hengshan-sword henshan-quan hua-quan
    huashan-quan huashan-quanfa huashan-zhang huashan-zhangfa hujia-quan hunyuan-zhang
    huzhua-shou jiasha-fumogong jieshou-jiushi jinding-zhang jinyu-quan jinyuan-gun
    jiuqu-zhegufa jiuyin-baiguzhao jueming-tui jueqing-zhang kongming-quan kunlun-zhang
    lanhua-shou leiming-bian lianhua-zhi lianhuan-mizongtui lingshe-quan lingxiao-quan
    liuhe-quan liuhe-zhang liumai-shenjian liuxing-chui liuyang-zhang liuyun-zhang
    longzhua-gong luoyan-jian luoying-shenzhang meinv-quan miaojia-zhang paiyun-shou
    panyang-zhang piaofeng-quan piaomiao-zhang piaoxu-zhang piaoxue-zhang pikong-zhang
    pili-quan pili-shou pobei-tui pokong-quan pona-gong poshui-zhang poxu-daxuefa
    poyu-quan poyue-zhao qiantian-zhi qilian-zhi qingmang-zhang qingyun-shou
    qinna-shibada qishang-quan qixing-quan qixing-shou qixing-zhi qujing-gunfa
    rulai-zhang ruying-suixingtui sanyin-shou sanyin-wugongzhao shangyang-sword
    shaochong-sword shaolin-quan shaolin-tantui shaoshang-sword shaoze-sword
    shedu-qiqiao shenfeng-bian shenlong-bashi shenzhang-bada shilin-jian shou-yin
    six-finger sixiang-zhang songshan-quan songshan-sword songshan-zhang sougu-yingzhua
    suohou-gong taishan-sword tan-tui tianchan-zhang tianchang-zhang tiangang-chenfa
    tianjue-dao tianluo-diwang tianzhu-fuzhi tianzhu-jian tie-zhang tiexian-quan
    tongbi-zhang tongchui-zhang woshi-zhang wudang-zhang wuluo-zhang wusheng-zhao
    wuxiang-zhi xiao-qinna xiaoyaoyou xiewei-bian xiuluo-zhi xuanfeng-tui xuangong-quan
    xumishan-zhang yanqing-quan yecha-gun yingzhua-gong yinhu-zhang yinlong-bian
    yinsuo-jinling yintuoluo-zhua yinyang-ren yinyang-zhang yipai-liangsan yitian-zhang
    yizhi-chan youming-zhi youshen-zhang yuezhao-gong yujiamu-quan yujian-shu
    yunlong-bian yunlong-shou yunlong-zhua yunu-sword yunv-jian yunzhou-fufa
    zhemei-shou zhenshan-zhang zhentian-quan zhenyu-quan zhongchong-sword zhongnan-zhi
    zhongping-qiang zigai-jian zilei-jian zuiquan-sanda
  )

  # ---- helpers ----

  defp stats(skills \\ %{}, attrs \\ %{}) do
    base = Stats.new()
    stats = %{base | skills: Map.merge(base.skills, skills)}
    Enum.reduce(attrs, stats, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  # 完整 Character 形状（practice 路径）：装备在 `meta.combat.equipped[:weapon]`
  defp char(opts \\ []) do
    equipped =
      case Keyword.get(opts, :weapon) do
        nil -> %{}
        type -> %{weapon: %{name: "长剑", skill_type: type}}
      end

    %{
      meta: %{
        vitals: %{
          max_neili: Keyword.get(opts, :max_neili, 20_000),
          neili: Keyword.get(opts, :neili, 20_000)
        },
        stats: %{shen: Keyword.get(opts, :shen, 100)},
        env: %{gender: Keyword.get(opts, :gender, "男性")},
        combat: %{equipped: equipped}
      }
    }
  end

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- 基础设施：三个判定器 ----

  describe "Kantele.Combat.Skill 持械判定器" do
    test "wielding?/1 读 meta.combat.equipped[:weapon]（LPC query_temp(\"weapon\")）" do
      refute Skill.wielding?(%{})
      refute Skill.wielding?(%{meta: %{combat: %{equipped: %{}}}})
      assert Skill.wielding?(char(weapon: "sword"))
      # 字符串键也认（老数据/序列化后的 map）
      assert Skill.wielding?(%{meta: %{combat: %{equipped: %{"weapon" => %{skill_type: "sword"}}}}})
    end

    test "secondary_wielding?/1 只看副手槽（主手武器不算）" do
      refute Skill.secondary_wielding?(char(weapon: "sword"))

      assert Skill.secondary_wielding?(%{
               meta: %{combat: %{equipped: %{secondary_weapon: %{skill_type: "dagger"}}}}
             })
    end

    test "wielded_skill_type/1 取武器原始 skill_type，空手为 nil" do
      assert Skill.wielded_skill_type(char(weapon: "sword")) == "sword"
      assert Skill.wielded_skill_type(char(weapon: "blade")) == "blade"
      assert Skill.wielded_skill_type(char()) == nil
      assert Skill.wielded_skill_type(%{}) == nil

      assert Skill.wielded_skill_type(%{
               meta: %{combat: %{equipped: %{weapon: %{"skill_type" => "whip"}}}}
             }) == "whip"
    end

    test "teach 事件切片形状（只有 meta.combat.equipped）同样可用" do
      slice = %{meta: %{vitals: %{max_neili: 1000}, combat: %{equipped: %{weapon: %{skill_type: "sword"}}}}}
      assert Skill.wielding?(slice)
      assert Skill.wielded_skill_type(slice) == "sword"
      refute Skill.secondary_wielding?(slice)
    end
  end

  # ---- 空手门（源 182 处 `weapon || secondary_weapon`）----

  test "changquan：先查百花错拳，再空手门，最后 lv（=本门等级）双门" do
    # 源 `int lv = me->query_skill("changquan", 1);` → lv 即本门等级
    assert_error("changquan", stats(%{"baihua-cuoquan" => 1}), char(), "你已经练成了百花错拳")
    assert_error("changquan", stats(), char(weapon: "sword"), "练太祖长拳必须空手")
    assert_error("changquan", stats(%{"unarmed" => 30, "cuff" => 30, "changquan" => 40}), char(), "你拳脚与拳法均火候不足")
    # 源是 `unarmed < lv && cuff < lv`：只要一门够即放行（保真的反直觉之处）
    assert :ok = learn("changquan", stats(%{"unarmed" => 40, "cuff" => 30, "changquan" => 40}), char())
    assert :ok = learn("changquan", stats(%{"unarmed" => 30, "cuff" => 40, "changquan" => 40}), char())
    assert :ok = learn("changquan", stats(%{"unarmed" => 40, "cuff" => 40, "changquan" => 40}), char())
  end

  test "baihua-quan：空手门 + 除法的等级门 div(unarmed,3) >= div(本门,2)" do
    assert_error("baihua-quan", stats(), char(weapon: "sword"), "练百花错拳必须空手")

    base = %{"force" => 150, "unarmed" => 200, "cuff" => 150, "hand" => 150, "claw" => 150, "strike" => 150}
    c = char(max_neili: 1500)

    # div(200,3)=66 < div(300,2)=150 → 拦
    assert_error("baihua-quan", stats(Map.put(base, "baihua-quan", 300)), c, "你的拳脚根基火候不足")
    # div(200,3)=66 >= div(100,2)=50 → 通过
    assert :ok = learn("baihua-quan", stats(Map.put(base, "baihua-quan", 100)), c)
  end

  # ---- 兵器类型门（源 `ob->query("skill_type")` 家族）----

  test "chongling-jian：必须持剑（空手与持刀都拦）" do
    base = %{"huashan-jian" => 100}
    c = char(max_neili: 100)

    assert_error("chongling-jian", stats(base), c, "你必须先找一把剑")
    assert_error("chongling-jian", stats(base), char(max_neili: 100, weapon: "blade"), "你必须先找一把剑")
    assert :ok = learn("chongling-jian", stats(base), char(max_neili: 100, weapon: "sword"))
  end

  test "yinyang-ren：剑或刀均可，其它武器与空手都拦" do
    base = %{"force" => 150, "sword" => 100, "blade" => 100}
    c = char(max_neili: 1800)

    assert_error("yinyang-ren", stats(base), c, "你使用的武器不对")
    assert_error("yinyang-ren", stats(base), char(max_neili: 1800, weapon: "whip"), "你使用的武器不对")

    assert :ok = learn("yinyang-ren", stats(base), char(max_neili: 1800, weapon: "sword"))
    assert :ok = learn("yinyang-ren", stats(base), char(max_neili: 1800, weapon: "blade"))
  end

  # ---- 端到端：teach 事件切片真的带上了装备 ----

  describe "skills/teach 事件转发 student_equipped" do
    test "学生空手 → 师父侧按持械门拒绝授艺" do
      teach("chongling-jian", %{})

      assert_receive %Event{
        topic: "skills/learn-result",
        data: %{failure_message: "你必须先找一把剑才能学习冲灵剑法。\n"}
      }
    end

    test "学生持刀 → 依然拒绝（剑法只认 sword）" do
      teach("chongling-jian", %{weapon: %{name: "柳叶刀", skill_type: "blade"}})

      assert_receive %Event{
        topic: "skills/learn-result",
        data: %{failure_message: "你必须先找一把剑才能学习冲灵剑法。\n"}
      }
    end

    test "学生持剑 → 门槛通过，正常授艺" do
      teach("chongling-jian", %{weapon: %{name: "长剑", skill_type: "sword"}})

      assert_receive %Event{topic: "skills/learn-result", data: %{skill: "chongling-jian"}}
    end

    test "student_equipped 缺失时按空手处理（不崩、不误放行）" do
      # 老调用方（未升级的命令/插件）不发该字段 → 切片回落 %{} → 空手
      SkillsEvent.teach(build_conn(teacher()), %{
        topic: "skills/teach",
        data: %{
          skill: "chongling-jian",
          times: 1,
          student_stats: student_stats(),
          student_vitals: Vitals.new(),
          reply_to: self()
        }
      })

      assert_receive %Event{
        topic: "skills/learn-result",
        data: %{failure_message: "你必须先找一把剑才能学习冲灵剑法。\n"}
      }
    end
  end

  defp teach(skill, equipped) do
    SkillsEvent.teach(build_conn(teacher()), %{
      topic: "skills/teach",
      data: %{
        skill: skill,
        times: 1,
        student_stats: student_stats(),
        student_vitals: Vitals.new(),
        student_equipped: equipped,
        reply_to: self()
      }
    })
  end

  defp teacher do
    base_character()
    |> Map.put(:name, "某师父")
    |> Map.put(:id, "npc-valid-learn-b2")
    |> Map.put(:meta, %PlayerMeta{
      vitals: Vitals.new(),
      stats: Map.put(Stats.new(), :skills, %{"chongling-jian" => 40}),
      combat: Kantele.Character.Combat.new()
    })
  end

  # 学生：max_neili 200（Vitals.new 默认）过 100 门，huashan-jian 100 过前置，
  # sword 0 与本门 0 相等 → 只剩持械门待判。
  defp student_stats do
    Stats.new()
    |> Map.put(:skills, %{"huashan-jian" => 100, "sword" => 0, "chongling-jian" => 0})
    |> Map.put(:potential, 500)
  end

  defp base_character do
    %Kalevala.Character{id: "player-1", name: "张三", pid: self(), room_id: "test:room"}
  end

  # ---- 覆盖性与健壮性 ----
  test "全部 178 个技能都已注册且带 valid_learn/2" do
    for id <- @generated do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end

  test "空手 / 持剑 / 缺切片三种形状下都不抛异常" do
    shapes = [
      %{},
      char(),
      char(weapon: "sword"),
      char(weapon: "whip", max_neili: 0, neili: 0, shen: -50, gender: "无性")
    ]

    for id <- @generated, shape <- shapes do
      case learn(id, stats(), shape) do
        :ok -> :ok
        {:error, message} -> assert is_binary(message) and message != "", "#{id} 文案异常"
        other -> flunk("#{id} 返回了非法值：#{inspect(other)}")
      end
    end
  end
end
