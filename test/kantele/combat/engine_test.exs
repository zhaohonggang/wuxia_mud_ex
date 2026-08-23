defmodule Kantele.Combat.EngineTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter

  # 固定随机源：返回列表中的下一个值（rng 语义为 1..n）
  defp seq_rng(values) do
    {:ok, agent} = Agent.start_link(fn -> values end)

    fn n ->
      Agent.get_and_update(agent, fn
        [v | rest] -> {min(v, n), rest}
        [] -> {n, []}
      end)
    end
  end

  defp max_rng(), do: fn n -> n end

  defp min_rng(), do: fn _n -> 1 end

  defp attacker(opts \\ []) do
    %Fighter{
      id: "attacker",
      name: "张三",
      pid: self(),
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 0,
      skills: %{"sword" => 1, "dodge" => 1, "parry" => 1},
      mapped: %{},
      applies: Keyword.get(opts, :applies, %{damage: 22, armor: 0}),
      busy: Keyword.get(opts, :busy, 0),
      jiali: 0,
      neili: 0,
      attack_skill: Keyword.get(opts, :attack_skill, "sword"),
      weapon_name: Keyword.get(opts, :weapon_name, "长剑")
    }
  end

  defp victim(opts \\ []) do
    %Fighter{
      id: "victim",
      name: "野猪",
      pid: self(),
      str: 16,
      dex: 20,
      con: 20,
      int: 6,
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      skills: %{"dodge" => 1, "parry" => 1},
      mapped: %{},
      applies: Keyword.get(opts, :applies, %{armor: 2}),
      busy: Keyword.get(opts, :busy, 0),
      neili: 0,
      attack_skill: "unarmed",
      weapon_name: nil
    }
  end

  describe "rand/2 (LPC random)" do
    test "returns 0..n-1" do
      assert Engine.rand(max_rng(), 10) == 9
      assert Engine.rand(min_rng(), 10) == 0
      assert Engine.rand(max_rng(), 1) == 0
      assert Engine.rand(max_rng(), 0) == 0
    end
  end

  describe "valid_power/1 经验边际递减" do
    test "阈值内原样返回" do
      assert Engine.valid_power(0) == 0
      assert Engine.valid_power(8000) == 8000
      assert Engine.valid_power(1_999_999) == 1_999_999
    end

    test "第一段折减为 1/10" do
      assert Engine.valid_power(2_000_000) == 2_000_000
      assert Engine.valid_power(2_500_000) == 2_000_000 + 50_000
    end

    test "第二段折减为 1/20" do
      assert Engine.valid_power(3_000_000) == 2_100_000
      assert Engine.valid_power(5_000_000) == 2_100_000 + 100_000
    end
  end

  describe "skill_power/3" do
    test "对照 LPC 手算：黑虎 unarmed 80 级、exp 8000、str 30" do
      heihu = %Fighter{
        Fighter.new()
        | str: 30,
          dex: 26,
          combat_exp: 8000,
          skills: %{"unarmed" => 80}
      }

      # level^3/10 + exp = 51200 + 8000 = 59200; 59200/30 = 1973; *30 = 59190
      assert Engine.skill_power(heihu, "unarmed", :attack) == 59_190
    end

    test "等级不足 1 时退化为 exp/2 * 属性 / 30（LPC 整除顺序）" do
      fighter = %Fighter{Fighter.new() | str: 30, dex: 26, combat_exp: 8000}

      # (valid_power(8000)/2)/30*str = 4000/30*30 = 133*30 = 3990
      assert Engine.skill_power(fighter, "unarmed", :attack) == 3990
      # 133*26 = 3458
      assert Engine.skill_power(fighter, "dodge", :defense) == 3458
    end

    test "apply 表的 attack/defense 加到等级上" do
      base = %{Fighter.new() | str: 30, skills: %{"unarmed" => 80}}

      boosted = %{base | applies: %{attack: 45}}

      # level 80：51200/30=1706; *30 = 51180
      assert Engine.skill_power(base, "unarmed", :attack) == 51_180

      # level 80+45=125：125^3/10 = 195312; /30=6510; *30 = 195300
      assert Engine.skill_power(boosted, "unarmed", :attack) == 195_300
    end

    test "等级超过 500 时按 level/10 * level^2 计算" do
      fighter = %{Fighter.new() | str: 10, dex: 20, skills: %{"force" => 600}}

      # defense 用身法：(60 * 600 * 600)/30 = 720000; *20 = 14400000
      assert Engine.skill_power(fighter, "force", :defense) == 14_400_000
    end
  end

  describe "attack_round/3 命中管线" do
    test "最小随机值必定闪避（random(ap+dp)=0 < dp）" do
      round = Engine.attack_round(attacker(), victim(), rng: min_rng())
      assert round.outcome == :dodge
    end

    test "最大随机值时命中并按公式结算伤害" do
      # rng 恒取最大：不闪避不招架，走完整伤害链
      #
      # base=22: damage=(22+21)/2=21；招式「基础挥砍」damage 6%：+1 => 22
      # 护甲 random(2)=1: wounded=21；con20 减 10% => 19
      # dex 卸力 random(100)=99 不触发
      round = Engine.attack_round(attacker(), victim(), rng: max_rng())

      assert round.outcome == :hit
      assert round.damage == 22
      assert round.wounded == 19
      assert round.jiali_spent == 0
    end

    test "scripted rng 可依次驱动闪避->招架判定" do
      # 第一掷（limb），第二掷 dodge 判定取最大 -> 不闪，
      # 第三掷 parry 判定取最小 -> 必招架
      rng = seq_rng([1, 2, 1])
      round = Engine.attack_round(attacker(), victim(), rng: rng)

      assert round.outcome == :parry
      assert round.damage == 0
    end

    test "busy 防守方被压制：dp/3 后原本必闪的攻击得以命中" do
      strong = %{victim() | skills: %{"dodge" => 300, "parry" => 300}}

      weak =
        attacker(
          attack_skill: "unarmed",
          weapon_name: nil,
          applies: %{unarmed_damage: 5}
        )

      dp = Engine.skill_power(strong, "dodge", :defense)

      # 取一个介于 div(dp,3) 与 dp 之间的随机值：
      # 正常防守 rand < dp -> 闪避；busy 后 dp/3 -> 不再闪避
      raw = div(dp, 2) + 2

      normal = Engine.attack_round(weak, strong, rng: seq_rng([1, raw]))
      busyed = Engine.attack_round(weak, %{strong | busy: 2}, rng: seq_rng([1, raw]))

      assert normal.outcome == :dodge
      assert busyed.outcome == :hit
    end

    test "持械对空手有 -10 招架 delta，空手对持械 +10" do
      # 通过行为差异验证：空手方攻击持械者更容易被招架
      armed_attacker = attacker()
      bare_victim = victim()

      armed_victim = %{victim() | weapon_name: "木剑", applies: %{armor: 2}}

      bare_attacker =
        attacker(
          attack_skill: "unarmed",
          weapon_name: nil,
          applies: %{unarmed_damage: 8}
        )

      # 边界 rng：让 parry 判定落在 delta 起作用的区间
      rng = seq_rng([1, 2, 2])

      hit_bare = Engine.attack_round(armed_attacker, bare_victim, rng: rng)

      rng = seq_rng([1, 2, 2])

      hit_armed = Engine.attack_round(bare_attacker, armed_victim, rng: rng)

      # 空手打持械：delta +10 提升防守 PP -> 该序列下招架成功
      assert hit_armed.outcome == :parry
      # 持械打空手：delta -10 -> 同序列下命中
      assert hit_bare.outcome == :hit
    end

    test "加力消耗内力换伤害加成" do
      attacker = %{attacker() | jiali: 50, neili: 100}

      round = Engine.attack_round(attacker, victim(), rng: max_rng())

      assert round.jiali_spent == 50

      # 内力不足以支付时不生效
      poor = %{attacker() | jiali: 50, neili: 40}

      round = Engine.attack_round(poor, victim(), rng: max_rng())

      assert round.jiali_spent == 0
    end

    test "伤害封顶：超高伤害按 (d-400)/4+300 折算" do
      monster = %Fighter{
        attacker()
        | applies: %{damage: 100_000},
          str: 100,
          con: 100,
          dex: 10
      }

      naked = %{victim() | applies: %{armor: 0}, dex: 10}

      round = Engine.attack_round(monster, naked, rng: max_rng())

      # damage = (100000+99999)/2 = 99999; +招式6%(5999) => 105998
      # 力量 bonus 100 => +(100+99)/3=66 => 106064
      # cap: (106064-400)/4+300 = 26699；con100 创伤 26699-24029=2670
      assert round.damage == 26_699
      assert round.wounded == 2670
    end
  end

  describe "select_action/1 招式选择" do
    test "映射特技按等级取表，未映射用通用拳脚" do
      with_mapped = %{
        attacker(attack_skill: "sword")
        | mapped: %{"sword" => "liuxin-jian"},
          skills: %{"liuxin-jian" => 70, "sword" => 70}
      }

      action = Engine.select_action(with_mapped)

      assert action["skill_name"] in ["杨柳依依", "拂柳分花", "飞絮无边", "柳浪闻莺"]

      bare = attacker(attack_skill: "unarmed", weapon_name: nil)

      action = Engine.select_action(%{bare | skills: %{"unarmed" => 5}})

      assert action["skill_name"] in ["挥拳猛击", "肘锤"]
    end
  end
end
