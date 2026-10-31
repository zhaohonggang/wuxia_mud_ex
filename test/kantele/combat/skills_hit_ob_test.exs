defmodule Kantele.Combat.SkillsHitObTest do
  @moduledoc """
  命中回调 `hit_ob/5` 迁移（C 相位 F4 长尾，Option 1：契约升级 + 纯额外创伤族）。

  LPC 契约：`mixed hit_ob(object me, object victim, int damage_bonus[, int factor])`
  ——定义在**攻击方**映射技能上，命中成立后按 `damage_bonus` 追加
  `victim->receive_wound("qi", …)` 并返回一句战斗文案。

  引擎旧契约是 `hit_ob/3(attacker, victim, action) :: map()`（只能改攻击方
  Fighter 的 delta，且在 `damage_calc` **之前**调用，拿不到 `damage_bonus`），
  与 LPC 语义不符，两个既有实现（dugu-jiujian / taiji-quan）都是空壳。
  本批改为 `hit_ob/5(attacker, victim, damage_bonus, factor, rng) ::
  {extra_wound, msg}`，在 `damage_calc` 内调用，`extra_wound` 计入本次创伤。

  本批只覆盖「纯额外创伤」族（无 affect_by 上毒 / 无 temp 激活态 / 无自伤 /
  无 userp 门）。`qishang-quan`（自伤反噬）与 `shenlong-baiwei`（`userp` 门）
  本批跳过；`gun`（巫师专用火枪，`valid_learn` 要 `wizardp`）亦跳过。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills.BizhenQingzhang
  alias Kantele.Combat.Skills.DabeiZhang
  alias Kantele.Combat.Skills.GuanchongSword
  alias Kantele.Combat.Skills.JiuquZhegufa
  alias Kantele.Combat.Skills.JiuyinBaiguzhao
  alias Kantele.Combat.Skills.PiaoxueZhang
  alias Kantele.Combat.Skills.PixieJian
  alias Kantele.Combat.Skills.SadStrike
  alias Kantele.Combat.Skills.ShangyangSword
  alias Kantele.Combat.Skills.ShaochongSword
  alias Kantele.Combat.Skills.ShaoshangSword
  alias Kantele.Combat.Skills.ShaozeSword
  alias Kantele.Combat.Skills.ShouYin
  alias Kantele.Combat.Skills.TieZhang
  alias Kantele.Combat.Skills.XianglongZhang
  alias Kantele.Combat.Skills.ZhongchongSword
  alias Kantele.Combat.Skills.FreezingForce
  alias Kantele.Combat.Skills.HanbingZhenqi
  alias Kantele.Combat.Skills.TaixuanGong
  alias Kantele.Combat.Skills.KuihuaMogong
  alias Kantele.Combat.Skills.ShenghuoShengong
  alias Kantele.Combat.Skills.YunvXinjing

  # ---- rng helpers（语义 1..n，与 Engine.rand 的 rng.(n)-1 对齐）----

  # 六脉/上阳剑族：LPC 六个技能 hit_ob 实现完全相同
  @sword_family [
    {GuanchongSword, "guanchong-sword"},
    {ShangyangSword, "shangyang-sword"},
    {ShaochongSword, "shaochong-sword"},
    {ShaoshangSword, "shaoshang-sword"},
    {ShaozeSword, "shaoze-sword"},
    {ZhongchongSword, "zhongchong-sword"}
  ]

  defp min_rng, do: fn _n -> 1 end
  defp max_rng, do: fn n -> n end

  # ---- 快照 helpers ----

  defp atk(skills, attrs \\ []) do
    %{skills: skills, str: 20, dex: 20, con: 20, int: 20}
    |> Map.merge(Map.new(attrs))
  end

  defp vic(skills \\ %{}, attrs \\ []) do
    %{skills: skills, str: 20, dex: 20, con: 20, int: 20}
    |> Map.merge(Map.new(attrs))
  end

  describe "force 对抗族（bizhen-qingzhang / dabei-zhang）" do
    test "bizhen-qingzhang：random(force) > 对手 force/2 时追加 (bonus-100)/2 创伤" do
      a = atk(%{"force" => 100})
      v = vic(%{"force" => 100})

      assert {50, msg} = BizhenQingzhang.hit_ob(a, v, 200, 0, max_rng())
      assert msg =~ "肋骨碎断"
    end

    test "bizhen-qingzhang：random 不足则不触发" do
      a = atk(%{"force" => 100})
      v = vic(%{"force" => 100})
      assert BizhenQingzhang.hit_ob(a, v, 200, 0, min_rng()) == {0, nil}
    end

    test "bizhen-qingzhang：damage_bonus < 100 直接不触发" do
      a = atk(%{"force" => 999})
      v = vic(%{"force" => 0})
      assert BizhenQingzhang.hit_ob(a, v, 99, 0, max_rng()) == {0, nil}
    end

    test "dabei-zhang：同型判定，文案为逼退" do
      a = atk(%{"force" => 100})
      v = vic(%{"force" => 100})

      assert {50, msg} = DabeiZhang.hit_ob(a, v, 200, 0, max_rng())
      assert msg =~ "逼退数步"

      assert DabeiZhang.hit_ob(a, v, 200, 0, min_rng()) == {0, nil}
      assert DabeiZhang.hit_ob(a, v, 99, 0, max_rng()) == {0, nil}
    end
  end

  describe "六脉/上阳剑族（random(bonus/4) > 对手 str）" do
    test "bonus>=100 且 random(bonus/4) > 对手 str 时追加 (bonus-100)/2 创伤" do
      for {mod, id} <- @sword_family do
        a = atk(%{id => 200})
        v = vic(%{}, str: 40)

        assert {50, msg} = mod.hit_ob(a, v, 200, 0, max_rng()), "#{id} 未触发"
        assert msg =~ "血滴", "#{id} 文案不符"
      end
    end

    test "random 不足 / bonus < 100 / str 过高 → 不触发" do
      for {mod, id} <- @sword_family do
        a = atk(%{id => 200})

        assert mod.hit_ob(a, vic(%{}, str: 40), 200, 0, min_rng()) == {0, nil}
        assert mod.hit_ob(a, vic(%{}, str: 40), 99, 0, max_rng()) == {0, nil}
        # bonus/4 = 50，49 > 50 不成立
        assert mod.hit_ob(a, vic(%{}, str: 50), 200, 0, max_rng()) == {0, nil}
      end
    end
  end

  describe "dex / str / con 对抗族" do
    test "jiuqu-zhegufa：bonus>=200 且 bonus/5 > 对手 dex" do
      a = atk(%{"jiuqu-zhegufa" => 200})
      v = vic(%{}, dex: 30)

      assert {50, msg} = JiuquZhegufa.hit_ob(a, v, 300, 0, max_rng())
      assert msg =~ "骨骼顿时应声而碎"

      assert JiuquZhegufa.hit_ob(a, v, 199, 0, max_rng()) == {0, nil}
      assert JiuquZhegufa.hit_ob(a, vic(%{}, dex: 60), 300, 0, max_rng()) == {0, nil}
    end

    test "jiuyin-baiguzhao：bonus>=100 且 bonus/5 > 对手 str" do
      a = atk(%{"jiuyin-baiguzhao" => 200})

      assert {50, msg} = JiuyinBaiguzhao.hit_ob(a, vic(%{}, str: 30), 200, 0, max_rng())
      assert msg =~ "骨骼碎裂"

      assert JiuyinBaiguzhao.hit_ob(a, vic(%{}, str: 30), 99, 0, max_rng()) == {0, nil}
      assert JiuyinBaiguzhao.hit_ob(a, vic(%{}, str: 40), 200, 0, max_rng()) == {0, nil}
    end

    test "sad-strike：bonus>=150 且 bonus/5 > 对手 str，创伤基数为 -100" do
      a = atk(%{"sad-strike" => 200})

      assert {50, msg} = SadStrike.hit_ob(a, vic(%{}, str: 30), 200, 0, max_rng())
      assert msg =~ "一大口鲜血"

      assert SadStrike.hit_ob(a, vic(%{}, str: 30), 149, 0, max_rng()) == {0, nil}
      assert SadStrike.hit_ob(a, vic(%{}, str: 40), 200, 0, max_rng()) == {0, nil}
    end

    test "shou-yin：bonus>=100 且 bonus/5 > 对手 str" do
      a = atk(%{"shou-yin" => 200})

      assert {50, msg} = ShouYin.hit_ob(a, vic(%{}, str: 30), 200, 0, max_rng())
      assert msg =~ "手印"

      assert ShouYin.hit_ob(a, vic(%{}, str: 40), 200, 0, max_rng()) == {0, nil}
    end

    test "piaoxue-zhang：bonus>=180、自身>=160 级、bonus/6 > 对手 con，创伤基数 -140/3" do
      a = atk(%{"piaoxue-zhang" => 160})

      assert {20, msg} = PiaoxueZhang.hit_ob(a, vic(%{}, con: 30), 200, 0, max_rng())
      assert msg =~ "一跟肋骨"

      assert PiaoxueZhang.hit_ob(a, vic(%{}, con: 30), 179, 0, max_rng()) == {0, nil}

      assert PiaoxueZhang.hit_ob(
               atk(%{"piaoxue-zhang" => 159}),
               vic(%{}, con: 30),
               200,
               0,
               max_rng()
             ) == {0, nil}

      assert PiaoxueZhang.hit_ob(a, vic(%{}, con: 33), 200, 0, max_rng()) == {0, nil}
    end
  end

  describe "con 对抗 + random(2) 族（tie-zhang / xianglong-zhang）" do
    test "tie-zhang：bonus>=150、自身>=150 级、bonus/6 > con 且 random(2)==1" do
      a = atk(%{"tie-zhang" => 150})
      v = vic(%{}, con: 30)

      # 首次 rng(2)=2 → 过 random(2)==1；二次 rng(2)=1 → 取第一条文案
      assert {35, msg} = TieZhang.hit_ob(a, v, 200, 0, seq_rng([2, 1]))
      assert msg =~ "肋骨断折"

      assert {35, msg2} = TieZhang.hit_ob(a, v, 200, 0, max_rng())
      assert msg2 =~ "鲜血狂喷"

      # random(2) != 1 → 不触发
      assert TieZhang.hit_ob(a, v, 200, 0, min_rng()) == {0, nil}
      assert TieZhang.hit_ob(a, v, 149, 0, max_rng()) == {0, nil}
      assert TieZhang.hit_ob(atk(%{"tie-zhang" => 149}), v, 200, 0, max_rng()) == {0, nil}
    end

    test "xianglong-zhang：bonus>=150、自身>=150 级、bonus/6 > con，创伤基数 -80/3" do
      a = atk(%{"xianglong-zhang" => 150})
      v = vic(%{}, con: 30)

      assert {40, msg} = XianglongZhang.hit_ob(a, v, 200, 0, max_rng())
      assert msg =~ "鲜血狂喷"

      assert {40, msg2} = XianglongZhang.hit_ob(a, v, 200, 0, seq_rng([1]))
      assert msg2 =~ "肋骨断折"

      assert XianglongZhang.hit_ob(a, v, 149, 0, max_rng()) == {0, nil}
      assert XianglongZhang.hit_ob(atk(%{"xianglong-zhang" => 149}), v, 200, 0, max_rng()) ==
               {0, nil}

      assert XianglongZhang.hit_ob(a, vic(%{}, con: 33), 200, 0, max_rng()) == {0, nil}
    end
  end

  describe "pixie-jian：random(10)>=5 且 >=200 级，两档创伤" do
    test "random(3) 非零 → (bonus-80)/4 档" do
      a = atk(%{"pixie-jian" => 200})
      assert {30, msg} = PixieJian.hit_ob(a, vic(), 200, 0, max_rng())
      assert msg =~ "渗出血丝"
    end

    test "random(3) 为零 → (bonus-80)/5 档（LPC 另有 jing 创伤，本模型未建模）" do
      a = atk(%{"pixie-jian" => 200})
      # n=10 → 10（random(10)=9 >= 5）；n=3 → 1（random(3)=0 → 走 else 分支）
      rng = fn n -> if n == 10, do: 10, else: 1 end
      assert {24, msg} = PixieJian.hit_ob(a, vic(), 200, 0, rng)
      assert msg =~ "数个穴位"
    end

    test "random(10)<5 / 等级不足 / bonus<=80 → 不触发" do
      a = atk(%{"pixie-jian" => 200})
      # n=10 → 5（random(10)=4，不满足 >=5）
      low = fn n -> if n == 10, do: 5, else: n end
      assert PixieJian.hit_ob(a, vic(), 200, 0, low) == {0, nil}

      assert PixieJian.hit_ob(atk(%{"pixie-jian" => 199}), vic(), 200, 0, max_rng()) ==
               {0, nil}

      assert PixieJian.hit_ob(a, vic(), 80, 0, max_rng()) == {0, nil}
    end
  end

  describe "引擎接线：damage_calc 内按 damage_bonus 调用并拼接文案" do
    test "命中后 hit_ob 触发，文案进 segments 且追加创伤" do
      a = fighter(%{
        attack_skill: "strike",
        mapped: %{"strike" => "xianglong-zhang"},
        skills: %{"strike" => 150, "force" => 100, "xianglong-zhang" => 150},
        str: 300,
        applies: %{damage: 200, armor: 0}
      })

      v = fighter(%{
        skills: %{"dodge" => 1, "parry" => 1},
        con: 10,
        applies: %{armor: 0}
      })

      round = Engine.attack_round(a, v, rng: max_rng())

      assert round.outcome == :hit
      assert Enum.any?(round.segments, &String.contains?(&1, "咔嚓"))
      assert round.wounded > 0
    end

    test "未映射到该技能时不出现该文案（回落 {0, nil}）" do
      a = fighter(%{
        attack_skill: "strike",
        mapped: %{},
        skills: %{"strike" => 150},
        str: 300,
        applies: %{damage: 200, armor: 0}
      })

      v = fighter(%{skills: %{"dodge" => 1, "parry" => 1}, con: 10, applies: %{armor: 0}})

      round = Engine.attack_round(a, v, rng: max_rng())
      refute Enum.any?(round.segments, &String.contains?(&1, "咔嚓"))
    end
  end

  # ---- helpers ----

  defp fighter(opts) do
    %Fighter{
      id: "f",
      name: "某",
      pid: self(),
      str: Map.get(opts, :str, 20),
      dex: 20,
      con: Map.get(opts, :con, 20),
      int: 20,
      combat_exp: 0,
      skills: Map.fetch!(opts, :skills),
      mapped: Map.get(opts, :mapped, %{}),
      applies: Map.get(opts, :applies, %{}),
      busy: 0,
      jiali: 0,
      neili: 0,
      attack_skill: Map.get(opts, :attack_skill, "unarmed"),
      weapon_name: nil
    }
  end

  # 顺序 rng：按 values 依次返回（用完循环），值会被 clamp 到 1..n
  defp seq_rng(values) do
    {:ok, agent} = Agent.start_link(fn -> values end)

    fn n ->
      Agent.get_and_update(agent, fn
        [v | rest] -> {min(v, n), if(rest == [], do: values, else: rest)}
        [] -> {n, []}
      end)
    end
  end

  # ---- 攻击方内功（force）命中回调：combatd.c:707 路径 ----

  describe "freezing-force 冰蚕寒劲被动（freezingbc 寒毒）" do
    @freezing_atk %{
      "freezing-force" => 200,
      "force" => 200
    }

    test "命中造成创伤 + lvl>=80 + jiali>=10 + 无兵器 + 压过对手 force → 上 freezingbc" do
      a = atk(@freezing_atk, jiali: 20, weapon_name: nil, id: "atk1")
      v = vic(%{"force" => 0})

      assert {0, msg, [{"freezingbc", para}]} =
               FreezingForce.hit_ob(a, v, 100, 0, max_rng())

      assert msg =~ "寒风袭体"
      assert para["id"] == "atk1"
      assert para["level"] == 39
      assert para["duration"] == 14
    end

    test "damage<=0 不触发" do
      a = atk(@freezing_atk, jiali: 20, weapon_name: nil, id: "atk1")
      assert FreezingForce.hit_ob(a, vic(), 0, 0, max_rng()) == {0, nil}
    end

    test "lvl<80 不触发" do
      a = atk(%{"freezing-force" => 50, "force" => 200}, jiali: 20, weapon_name: nil, id: "x")
      assert FreezingForce.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "jiali<10 不触发" do
      a = atk(@freezing_atk, jiali: 5, weapon_name: nil, id: "x")
      assert FreezingForce.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "持械不触发" do
      a = atk(@freezing_atk, jiali: 20, weapon_name: "长剑", id: "x")
      assert FreezingForce.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "对手 force 过高（jiali*2 + random 压不过）不触发" do
      a = atk(@freezing_atk, jiali: 20, weapon_name: nil, id: "x")
      v = vic(%{"force" => 999_999})
      assert FreezingForce.hit_ob(a, v, 100, 0, min_rng()) == {0, nil}
    end
  end

  describe "hanbing-zhenqi 寒冰真气冰封被动（freezing 寒毒）" do
    @hanbing_atk %{
      "hanbing-zhenqi" => 300,
      "force" => 300
    }

    setup do
      [
        atk_base: [
          jiali: 120,
          neili: 900,
          freezing_buff: true,
          weapon_name: nil,
          id: "atk2"
        ]
      ]
    end

    test "全门通过 + 已运 freezing + 压过对手 force → 上 freezing（level=flvl*3）", ctx do
      a = atk(@hanbing_atk, ctx.atk_base)
      v = vic(%{"force" => 0})

      assert {0, msg, [{"freezing", para}]} =
               HanbingZhenqi.hit_ob(a, v, 100, 0, max_rng())

      # max_rng 下 random(2)==1 → 第一条文案；level=flvl*3=360
      assert msg =~ "接下"
      assert para["id"] == "atk2"
      assert para["level"] == 360
      assert para["duration"] == 20
    end

    test "neili<500 不触发", ctx do
      a = atk(@hanbing_atk, Keyword.put(ctx.atk_base, :neili, 400))
      assert HanbingZhenqi.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "lvl<220 不触发", ctx do
      a = atk(%{"hanbing-zhenqi" => 100, "force" => 300}, ctx.atk_base)
      assert HanbingZhenqi.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "jiali<100 不触发", ctx do
      a = atk(@hanbing_atk, Keyword.put(ctx.atk_base, :jiali, 50))
      assert HanbingZhenqi.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "random(2) 门不过不触发", ctx do
      a = atk(@hanbing_atk, ctx.atk_base)
      assert HanbingZhenqi.hit_ob(a, vic(%{"force" => 0}), 100, 0, min_rng()) == {0, nil}
    end

    test "未运寒冰真气（freezing_buff=false）不触发", ctx do
      a = atk(@hanbing_atk, Keyword.put(ctx.atk_base, :freezing_buff, false))
      assert HanbingZhenqi.hit_ob(a, vic(%{"force" => 0}), 100, 0, max_rng()) == {0, nil}
    end

    test "对手 force 过高（jiali*2 + random(lvl) 压不过）不触发", ctx do
      a = atk(@hanbing_atk, ctx.atk_base)
      v = vic(%{"force" => 1000})
      assert HanbingZhenqi.hit_ob(a, v, 100, 0, max_rng()) == {0, nil}
    end
  end

  # ---- 攻击方内功 force 路径：纯额外创伤 / 多段连击（combatd.c:707）----
  # taixuan / kuihua / shenghuo / yunv-xinjing。多段 do_attack 连击在本引擎单轮无通道，
  # 仅还原「文案」；自耗/抽干内力、learned/wall/prepared 门控未建模（按满足近似）。
  describe "force 路径（taixuan / kuihua / shenghuo / yunv-xinjing）" do
    test "taixuan-gong 空手触发：db>=150/lvl>=140/neili>=300 + db/5>对手con → 追加 (db-76)/2" do
      a = atk(%{"taixuan-gong" => 200},
        mapped: %{"force" => "taixuan-gong"}, neili: 500, weapon_name: nil, id: "x")
      v = vic(%{}, con: 5)

      assert {62, msg, []} = TaixuanGong.hit_ob(a, v, 200, 0, min_rng())
      assert msg =~ "太玄内劲"
    end

    test "taixuan-gong 负门：db<150 / lvl<140 / neili<300 / random(2) / con过高 / 非刀剑" do
      base = fn wn, wst, sw, bl ->
        atk(%{"taixuan-gong" => 200},
          mapped:
            Map.merge(%{"force" => "taixuan-gong"},
              [{"sword", sw}, {"blade", bl}]
              |> Enum.reject(fn {_, v} -> is_nil(v) end)
              |> Map.new()
            ),
          neili: 500, weapon_name: wn, weapon_skill_type: wst, id: "x")
      end

      v_low = vic(%{}, con: 5)
      v_high = vic(%{}, con: 50)

      assert TaixuanGong.hit_ob(base.(nil, nil, nil, nil), v_low, 100, 0, min_rng()) == {0, nil}
      assert TaixuanGong.hit_ob(atk(%{"taixuan-gong" => 100}, mapped: %{"force" => "taixuan-gong"}, neili: 500, weapon_name: nil, id: "x"), v_low, 200, 0, min_rng()) == {0, nil}
      assert TaixuanGong.hit_ob(atk(%{"taixuan-gong" => 200}, mapped: %{"force" => "taixuan-gong"}, neili: 200, weapon_name: nil, id: "x"), v_low, 200, 0, min_rng()) == {0, nil}
      assert TaixuanGong.hit_ob(base.(nil, nil, nil, nil), v_low, 200, 0, max_rng()) == {0, nil}
      assert TaixuanGong.hit_ob(base.(nil, nil, nil, nil), v_high, 200, 0, min_rng()) == {0, nil}
      assert TaixuanGong.hit_ob(base.("长棍", "staff", nil, nil), v_low, 200, 0, min_rng()) == {0, nil}
    end

    test "taixuan-gong 持刀/剑且 mapped 对应 → 触发" do
      a_sword =
        atk(%{"taixuan-gong" => 200},
          mapped: %{"force" => "taixuan-gong", "sword" => "taixuan-gong"},
          neili: 500, weapon_name: "长剑", weapon_skill_type: "sword", id: "x")

      a_blade =
        atk(%{"taixuan-gong" => 200},
          mapped: %{"force" => "taixuan-gong", "blade" => "taixuan-gong"},
          neili: 500, weapon_name: "戒刀", weapon_skill_type: "blade", id: "x")

      v = vic(%{}, con: 5)
      assert {62, msg, []} = TaixuanGong.hit_ob(a_sword, v, 200, 0, min_rng())
      assert msg =~ "太玄内劲"
      assert {62, _msg, []} = TaixuanGong.hit_ob(a_blade, v, 200, 0, min_rng())
    end

    test "kuihua-mogong 触发（多段连击，仅还原文案）：rand(2)!=0 + db>=120 + neili>=300 + lvl>=200" do
      a = atk(%{"kuihua-mogong" => 250}, neili: 500, weapon_name: nil, id: "x")
      assert {0, msg, []} = KuihuaMogong.hit_ob(a, vic(), 200, 0, max_rng())
      assert msg =~ "化分为无数身影"
    end

    test "kuihua-mogong 负门：rand(2)==0 / db<120 / neili<300 / lvl<200" do
      a = atk(%{"kuihua-mogong" => 250}, neili: 500, weapon_name: nil, id: "x")
      assert KuihuaMogong.hit_ob(a, vic(), 200, 0, min_rng()) == {0, nil}
      assert KuihuaMogong.hit_ob(atk(%{"kuihua-mogong" => 250}, neili: 500, weapon_name: nil, id: "x"), vic(), 100, 0, max_rng()) == {0, nil}
      assert KuihuaMogong.hit_ob(atk(%{"kuihua-mogong" => 250}, neili: 200, weapon_name: nil, id: "x"), vic(), 200, 0, max_rng()) == {0, nil}
      assert KuihuaMogong.hit_ob(atk(%{"kuihua-mogong" => 100}, neili: 500, weapon_name: nil, id: "x"), vic(), 200, 0, max_rng()) == {0, nil}
    end

    test "shenghuo-shengong 触发：全门通过 + lvl/2+random(lvl)>对手force → 还原文案" do
      a =
        atk(%{"shenghuo-shengong" => 300, "shenghuo-ling" => 200},
          mapped: %{"force" => "shenghuo-shengong", "sword" => "shenghuo-ling"},
          neili: 500, weapon_name: "圣火令", weapon_skill_type: "sword", id: "x")

      v = vic(%{"force" => 0})
      assert {0, msg, []} = ShenghuoShengong.hit_ob(a, v, 200, 0, max_rng())
      assert msg =~ "剑招连绵"
    end

    test "shenghuo-shengong 负门：lvl<140 / 无兵器 / 非剑 / mapped不符 / 对手force过高" do
      base =
        atk(%{"shenghuo-shengong" => 300, "shenghuo-ling" => 200},
          mapped: %{"force" => "shenghuo-shengong", "sword" => "shenghuo-ling"},
          neili: 500, weapon_name: "圣火令", weapon_skill_type: "sword", id: "x")

      assert ShenghuoShengong.hit_ob(atk(%{"shenghuo-shengong" => 100, "shenghuo-ling" => 200}, mapped: %{"force" => "shenghuo-shengong", "sword" => "shenghuo-ling"}, neili: 500, weapon_name: "圣火令", weapon_skill_type: "sword", id: "x"), vic(%{"force" => 0}), 200, 0, max_rng()) == {0, nil}
      assert ShenghuoShengong.hit_ob(atk(%{"shenghuo-shengong" => 300, "shenghuo-ling" => 200}, mapped: %{"force" => "shenghuo-shengong", "sword" => "shenghuo-ling"}, neili: 500, weapon_name: nil, weapon_skill_type: nil, id: "x"), vic(%{"force" => 0}), 200, 0, max_rng()) == {0, nil}
      assert ShenghuoShengong.hit_ob(atk(%{"shenghuo-shengong" => 300, "shenghuo-ling" => 200}, mapped: %{"force" => "shenghuo-shengong", "sword" => "shenghuo-ling"}, neili: 500, weapon_name: "刀", weapon_skill_type: "blade", id: "x"), vic(%{"force" => 0}), 200, 0, max_rng()) == {0, nil}
      assert ShenghuoShengong.hit_ob(atk(%{"shenghuo-shengong" => 300, "shenghuo-ling" => 200}, mapped: %{"force" => "other", "sword" => "shenghuo-ling"}, neili: 500, weapon_name: "圣火令", weapon_skill_type: "sword", id: "x"), vic(%{"force" => 0}), 200, 0, max_rng()) == {0, nil}
      # 对手 force 过高：lvl/2+rand(lvl)<=对手force（min_rng 使 rand=0 → 150<=200）
      assert ShenghuoShengong.hit_ob(base, vic(%{"force" => 200}), 200, 0, min_rng()) == {0, nil}
    end

    test "yunv-xinjing sword 分支：全门通过 + mapped sword==suxin-jian → 追加 lvl/5*5/3 qi" do
      a =
        atk(%{"yunv-xinjing" => 300, "force" => 300},
          mapped: %{"force" => "yunv-xinjing", "sword" => "suxin-jian"},
          neili: 500, weapon_name: "玉女剑", weapon_skill_type: "sword", id: "x")

      v = vic(%{}, con: 0)
      assert {100, msg, []} = YunvXinjing.hit_ob(a, v, 200, 0, min_rng())
      assert msg =~ "玉女心经"
    end

    test "yunv-xinjing whip 分支：mapped whip==yinsuo-jinling → 追加 lvl/4*5/3 qi" do
      a =
        atk(%{"yunv-xinjing" => 300, "force" => 300},
          mapped: %{"force" => "yunv-xinjing", "whip" => "yinsuo-jinling"},
          neili: 500, weapon_name: "银索金铃", weapon_skill_type: "whip", id: "x")

      v = vic(%{}, con: 0)
      assert {125, msg, []} = YunvXinjing.hit_ob(a, v, 200, 0, min_rng())
      assert msg =~ "玉女心经"
    end

    test "yunv-xinjing 负门：lvl<150 / neili<300 / 无兵器 / rand(3)>1 / 非刀剑鞭" do
      base =
        atk(%{"yunv-xinjing" => 300, "force" => 300},
          mapped: %{"force" => "yunv-xinjing", "sword" => "suxin-jian"},
          neili: 500, weapon_name: "玉女剑", weapon_skill_type: "sword", id: "x")

      v = vic(%{}, con: 0)
      assert YunvXinjing.hit_ob(atk(%{"yunv-xinjing" => 100, "force" => 300}, mapped: %{"force" => "yunv-xinjing", "sword" => "suxin-jian"}, neili: 500, weapon_name: "玉女剑", weapon_skill_type: "sword", id: "x"), v, 200, 0, min_rng()) == {0, nil}
      assert YunvXinjing.hit_ob(atk(%{"yunv-xinjing" => 300, "force" => 300}, mapped: %{"force" => "yunv-xinjing", "sword" => "suxin-jian"}, neili: 200, weapon_name: "玉女剑", weapon_skill_type: "sword", id: "x"), v, 200, 0, min_rng()) == {0, nil}
      assert YunvXinjing.hit_ob(atk(%{"yunv-xinjing" => 300, "force" => 300}, mapped: %{"force" => "yunv-xinjing", "sword" => "suxin-jian"}, neili: 500, weapon_name: nil, weapon_skill_type: nil, id: "x"), v, 200, 0, min_rng()) == {0, nil}
      assert YunvXinjing.hit_ob(base, v, 200, 0, max_rng()) == {0, nil}
      assert YunvXinjing.hit_ob(atk(%{"yunv-xinjing" => 300, "force" => 300}, mapped: %{"force" => "yunv-xinjing", "sword" => "suxin-jian"}, neili: 500, weapon_name: "刀", weapon_skill_type: "blade", id: "x"), v, 200, 0, min_rng()) == {0, nil}
    end
  end
end
