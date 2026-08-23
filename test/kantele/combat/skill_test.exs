defmodule Kantele.Combat.SkillTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Messages
  alias Kantele.Combat.Skill
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LiuxinJian
  alias Kantele.Character.Stats

  describe "new_random/2（LPC NewRandom 加权）" do
    test "n=0/1 边界" do
      assert Skill.new_random(0, fn _ -> 1 end) == 0
      assert Skill.new_random(1, fn _ -> 1 end) == 0
    end

    test "n=2 时恒返回 0（对照 LPC 行为）" do
      rng = fn n -> n end
      assert Skill.new_random(2, rng) == 0
      assert Skill.new_random(2, fn _ -> 1 end) == 0
    end

    test "结果落在可用招式范围内且偏向后段" do
      rng = fn n -> n end
      results = for _ <- 1..200, do: Skill.new_random(10, rng)

      # max rng：random(sum)=sum-1，触发在最后一步 -> 恒为 n-1
      assert Enum.uniq(results) == [9]

      seeded = :rand.seed(:exsss, {101, 102, 103})
      samples = for _ <- 1..2000, do: Skill.new_random(10, &:rand.uniform/1)
      :rand.seed(seeded)

      assert Enum.all?(samples, &(&1 in 4..9))
      # 权重偏向高段：均值明显高于均匀分布中值 (4+9)/2 = 6.5 的下界
      mean = Enum.sum(samples) / length(samples)
      assert mean > 7.0
    end
  end

  describe "pick_action/3 等级门槛" do
    test "只从 lvl < level 的招式中选取" do
      actions = LiuxinJian.actions()

      action = Skill.pick_action(actions, 30, fn _ -> 1 end)
      assert action["lvl"] < 30

      # 等级不足时回退到第一式
      action = Skill.pick_action(actions, 0, fn _ -> 1 end)
      assert action["skill_name"] == "杨柳依依"
    end
  end

  describe "柳心剑法" do
    test "valid_enable 与学习门槛" do
      assert LiuxinJian.valid_enable("sword")
      assert LiuxinJian.valid_enable("parry")
      refute LiuxinJian.valid_enable("unarmed")

      low_force = %Stats{Stats.new() | skills: %{"force" => 10}}
      assert {:error, _} = LiuxinJian.valid_learn(low_force)

      base_too_low = %Stats{
        Stats.new()
        | skills: %{"force" => 30, "sword" => 5, "liuxin-jian" => 5}
      }

      assert {:error, _} = LiuxinJian.valid_learn(base_too_low)

      ok = %Stats{Stats.new() | skills: %{"force" => 30, "sword" => 10}}
      assert :ok = LiuxinJian.valid_learn(ok)
    end

    test "practice_cost 对照 liuxin-jian.c" do
      assert LiuxinJian.practice_cost() == %{qi: 55, neili: 38}
    end

    test "绝招表包含柳浪闻莺" do
      assert LiuxinJian.perform_list()["liu"] == Kantele.Combat.Skills.LiuxinJian.Liu
    end

    test "query_skill_name 按等级取最高已解锁招式名" do
      assert LiuxinJian.query_skill_name(0) == "杨柳依依"
      assert LiuxinJian.query_skill_name(25) == "拂柳分花"
      assert LiuxinJian.query_skill_name(200) == "万缕垂青"
    end
  end

  describe "柳溪内功" do
    test "只能 enable 到 force 且不可 practice" do
      neigong = Skills.get("liuxi-neigong")

      assert neigong.id() == "liuxi-neigong"
      assert neigong.valid_enable("force")
      refute neigong.valid_enable("sword")
      assert neigong.practice_cost() == nil
      assert neigong.exert_list()["powerup"] == Kantele.Combat.Skills.LiuxiNeigong.Powerup
    end
  end

  describe "Messages 文案库" do
    test "占位符替换" do
      text =
        Messages.interpolate(
          "$N挥剑刺向$n的$l！",
          n1: "张三",
          n2: "黑虎",
          limb: "胸口",
          weapon: "长剑"
        )

      assert text == "张三挥剑刺向黑虎的胸口！"

      text = Messages.interpolate("$w砍中$p", weapon: "木剑", n2: "野猪")

      assert text == "木剑砍中野猪"
    end

    test "伤害分级文案全档位非空且随档位变化" do
      tiers = [0, 20, 60, 150, 300, 500]

      texts =
        Enum.map(tiers, fn damage ->
          Messages.damage_msg(damage, "刺伤")
        end)

      assert Enum.all?(texts, &is_binary/1)
      assert Enum.uniq(texts) == texts

      # 缺失类型回退
      assert Messages.damage_msg(50, nil) == Messages.no_damage_msg()
    end

    test "气血状态描述分档" do
      assert Messages.eff_status_msg(100) =~ "气血充盈"
      assert Messages.eff_status_msg(50) =~ "气息粗重"
      assert Messages.eff_status_msg(0) =~ "风中残烛"
    end
  end
end
