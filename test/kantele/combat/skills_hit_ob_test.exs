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
end
