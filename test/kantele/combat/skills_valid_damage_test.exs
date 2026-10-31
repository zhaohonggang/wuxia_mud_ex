defmodule Kantele.Combat.Skills.ValidDamageTest do
  @moduledoc """
  valid_damage/5 全量校验（C 相位 F4 收官后新增的防守方伤害再判定钩子，27 技能全部覆盖）

  仅校验移植后的逻辑本身（对照 LPC valid_damage）：
  - 等级/兵刃门槛正确；
  - 触发时伤害被化解为 0 且带文案；
  - 引擎侧 apply_defender_valid_damage 的接线由全量回归覆盖。
  """

  use ExUnit.Case, async: true

  # 固定 rng：恒返回 1 -> rng.(n) - 1 == 0（决定论地让化解判定胜出，取第 0 条文案）
  defp zero_rng(), do: fn _n -> 1 end

  # 固定 rng：恒返回 2 -> rng.(n) - 1 == 1（用于 random(2) != 1 门：0 != 1 为跳过，1 为通过）
  defp two_rng(), do: fn _n -> 2 end

  # 攻击方快照（只暴露 valid_damage/5 读取的字段）
  defp attacker(opts) do
    %{
      skills:
        Keyword.get(opts, :skills, %{
          "force" => 100,
          "count" => 0,
          "dodge" => 100,
          "parry" => 100
        }),
      weapon_name: Keyword.get(opts, :weapon),
      jiali: Keyword.get(opts, :jiali, 10),
      max_neili: Keyword.get(opts, :max_neili, 1000),
      mapped: Keyword.get(opts, :mapped, %{})
    }
  end

  # 防守方快照
  defp victim(opts) do
    %{
      skills: Keyword.get(opts, :skills, %{}),
      weapon_name: Keyword.get(opts, :weapon),
      weapon_skill_type: Keyword.get(opts, :weapon_skill_type),
      busy: Keyword.get(opts, :busy, 0),
      neili: Keyword.get(opts, :neili, 500),
      max_neili: Keyword.get(opts, :max_neili, 1000),
      mapped: Keyword.get(opts, :mapped, %{})
    }
  end

  # ─────────────────────────────
  # beiming-shengong（需 skill>=70，attacker force != taixuan-gong，attacker.jiali>=1）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.BeimingShengong

  describe "beiming-shengong valid_damage" do
    test "等级达标且无 taixuan-gong -> 化解" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"beiming-shengong" => 150, "force" => 200})
      assert {0, _msg} = BeimingShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"beiming-shengong" => 50, "force" => 200})
      assert {50, nil} = BeimingShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "attacker 运行 taixuan-gong -> 原样返还" do
      atk = attacker(skills: %{"force" => 100}, mapped: %{"force" => "taixuan-gong"})
      vic = victim(skills: %{"beiming-shengong" => 150, "force" => 200})
      assert {50, nil} = BeimingShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "attacker jiali=0 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100}, jiali: 0)
      vic = victim(skills: %{"beiming-shengong" => 150, "force" => 200})
      assert {50, nil} = BeimingShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # dafumo-quan（需 skill>=100，双方空手）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.DafumoQuan

  describe "dafumo-quan valid_damage" do
    test "双方空手且等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"dafumo-quan" => 150, "unarmed" => 100})
      assert {0, _msg} = DafumoQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"dafumo-quan" => 150, "unarmed" => 100}, weapon: "长剑")
      assert {50, nil} = DafumoQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"dafumo-quan" => 50, "unarmed" => 100})
      assert {50, nil} = DafumoQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # dagou-bang（需 skill>=100，防守方持 staff 兵刃）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.DagouBang

  describe "dagou-bang valid_damage" do
    test "持棍且等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic =
        victim(
          skills: %{"dagou-bang" => 150, "parry" => 100},
          weapon: "打狗棒",
          weapon_skill_type: "staff"
        )

      assert {0, _msg} = DagouBang.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方无兵刃 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"dagou-bang" => 150, "parry" => 100})
      assert {50, nil} = DagouBang.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic =
        victim(
          skills: %{"dagou-bang" => 50, "parry" => 100},
          weapon: "打狗棒",
          weapon_skill_type: "staff"
        )

      assert {50, nil} = DagouBang.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # douzhuan-xingyi（需 skill>=100，zihui-xinfa>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.DouzhuanXingyi

  describe "douzhuan-xingyi valid_damage" do
    test "双门槛达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"douzhuan-xingyi" => 150, "zihui-xinfa" => 150, "parry" => 200})
      assert {0, _msg} = DouzhuanXingyi.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"douzhuan-xingyi" => 50, "zihui-xinfa" => 150, "parry" => 200})
      assert {50, nil} = DouzhuanXingyi.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "zihui-xinfa 不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"douzhuan-xingyi" => 150, "zihui-xinfa" => 50, "parry" => 200})
      assert {50, nil} = DouzhuanXingyi.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # huagong-dafa（需 skill>=80，attacker.jiali>=1）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.HuagongDafa

  describe "huagong-dafa valid_damage" do
    test "等级达标且 jiali>=1 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "dodge" => 100})
      vic = victim(skills: %{"huagong-dafa" => 100, "force" => 100, "dodge" => 100})
      assert {0, _msg} = HuagongDafa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "jiali=0 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "dodge" => 100}, jiali: 0)
      vic = victim(skills: %{"huagong-dafa" => 100, "force" => 100, "dodge" => 100})
      assert {50, nil} = HuagongDafa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "dodge" => 100})
      vic = victim(skills: %{"huagong-dafa" => 50, "force" => 100, "dodge" => 100})
      assert {50, nil} = HuagongDafa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # jingang-buhuaiti（需 skill>=100，victim.neili>=300，attacker 无兵刃）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.JingangBuhuaiti

  describe "jingang-buhuaiti valid_damage" do
    test "门槛达标 -> 化解" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic = victim(skills: %{"jingang-buhuaiti" => 150, "force" => 100}, neili: 500)
      assert {0, _msg} = JingangBuhuaiti.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "attacker 持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, weapon: "长剑")
      vic = victim(skills: %{"jingang-buhuaiti" => 150, "force" => 100}, neili: 500)
      assert {50, nil} = JingangBuhuaiti.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10})
      vic = victim(skills: %{"jingang-buhuaiti" => 50, "force" => 100}, neili: 500)
      assert {50, nil} = JingangBuhuaiti.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # jinguan-yusuo（需 skill>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.JinguanYusuo

  describe "jinguan-yusuo valid_damage" do
    test "等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"jinguan-yusuo" => 150})
      assert {0, _msg} = JinguanYusuo.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"jinguan-yusuo" => 50})
      assert {50, nil} = JinguanYusuo.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # jinzhong-zhao（需 skill>=150，victim.neili>=400，attacker 无兵刃）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.JinzhongZhao

  describe "jinzhong-zhao valid_damage" do
    test "门槛达标 -> 化解" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 0)
      vic = victim(skills: %{"jinzhong-zhao" => 150, "force" => 100}, neili: 500)
      assert {0, _msg} = JinzhongZhao.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "attacker 持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 0, weapon: "长剑")
      vic = victim(skills: %{"jinzhong-zhao" => 150, "force" => 100}, neili: 500)
      assert {50, nil} = JinzhongZhao.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 0)
      vic = victim(skills: %{"jinzhong-zhao" => 100, "force" => 100}, neili: 500)
      assert {50, nil} = JinzhongZhao.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # jiuyang-shengong（需 skill>=150，parry/force/unarmed 均映射自身，neili>=500，attacker 无兵刃，random(2)==1）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.JiuyangShengong

  describe "jiuyang-shengong valid_damage" do
    test "三项均映射自身且 neili 充足 -> 化解" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic =
        victim(
          skills: %{"jiuyang-shengong" => 150, "force" => 100},
          neili: 500,
          mapped: %{
            "parry" => "jiuyang-shengong",
            "force" => "jiuyang-shengong",
            "unarmed" => "jiuyang-shengong"
          }
        )

      assert {0, _msg} = JiuyangShengong.valid_damage(atk, vic, 50, %{}, two_rng())
    end

    test "攻击方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000, weapon: "长剑")
      vic =
        victim(
          skills: %{"jiuyang-shengong" => 150, "force" => 100},
          neili: 500,
          mapped: %{
            "parry" => "jiuyang-shengong",
            "force" => "jiuyang-shengong",
            "unarmed" => "jiuyang-shengong"
          }
        )

      assert {50, nil} = JiuyangShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic =
        victim(
          skills: %{"jiuyang-shengong" => 100, "force" => 100},
          neili: 500,
          mapped: %{
            "parry" => "jiuyang-shengong",
            "force" => "jiuyang-shengong",
            "unarmed" => "jiuyang-shengong"
          }
        )

      assert {50, nil} = JiuyangShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # jiuyin-shengong（需 skill>=150，parry/force 均映射自身，neili>=500，attacker 无兵刃，random(2)==1）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.JiuyinShengong

  describe "jiuyin-shengong valid_damage" do
    test "parry/force 均映射自身且 neili 充足 -> 化解" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic =
        victim(
          skills: %{"jiuyin-shengong" => 150, "force" => 100},
          neili: 500,
          mapped: %{"parry" => "jiuyin-shengong", "force" => "jiuyin-shengong"}
        )

      assert {0, _msg} = JiuyinShengong.valid_damage(atk, vic, 50, %{}, two_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic =
        victim(
          skills: %{"jiuyin-shengong" => 100, "force" => 100},
          neili: 500,
          mapped: %{"parry" => "jiuyin-shengong", "force" => "jiuyin-shengong"}
        )

      assert {50, nil} = JiuyinShengong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # kongming-quan（pilot，保留）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.KongmingQuan

  describe "kongming-quan valid_damage" do
    test "双方空手且等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"kongming-quan" => 150, "unarmed" => 100})
      assert {0, _msg} = KongmingQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"kongming-quan" => 150, "unarmed" => 100}, weapon: "长剑")
      assert {50, nil} = KongmingQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"kongming-quan" => 50, "unarmed" => 100})
      assert {50, nil} = KongmingQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # kuihua-mogong（需 skill>=210，victim dodge 映射自身）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.KuihuaMogong

  describe "kuihua-mogong valid_damage" do
    test "dodge 映射自身且等级达标 -> 化解" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic =
        victim(
          skills: %{"kuihua-mogong" => 250, "dodge" => 200},
          mapped: %{"dodge" => "kuihua-mogong"}
        )

      assert {0, _msg} = KuihuaMogong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic =
        victim(
          skills: %{"kuihua-mogong" => 100, "dodge" => 200},
          mapped: %{"dodge" => "kuihua-mogong"}
        )

      assert {50, nil} = KuihuaMogong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # lingbo-weibu（需 skill>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.LingboWeibu

  describe "lingbo-weibu valid_damage" do
    test "等级达标 -> 化解" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"lingbo-weibu" => 150, "dodge" => 200})
      assert {0, _msg} = LingboWeibu.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"lingbo-weibu" => 50, "dodge" => 200})
      assert {50, nil} = LingboWeibu.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # pixie-jian（需 skill>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.PixieJian

  describe "pixie-jian valid_damage" do
    test "等级达标 -> 化解" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"pixie-jian" => 150, "dodge" => 200})
      assert {0, _msg} = PixieJian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"pixie-jian" => 50, "dodge" => 200})
      assert {50, nil} = PixieJian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # qiankun-danuoyi（需 skill>=100；zero_rng 下 rng.(30)-1 != 1，走卸招分支）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.QiankunDanuoyi

  describe "qiankun-danuoyi valid_damage" do
    test "等级达标且卸招判定胜出 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"qiankun-danuoyi" => 150, "parry" => 200})
      assert {0, _msg} = QiankunDanuoyi.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"qiankun-danuoyi" => 50, "parry" => 200})
      assert {50, nil} = QiankunDanuoyi.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # qingfu-shenfa（需 skill>=100，random(2)==1）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.QingfuShenfa

  describe "qingfu-shenfa valid_damage" do
    test "等级达标且 random(2)==1 -> 化解" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"qingfu-shenfa" => 150, "dodge" => 200})
      assert {0, _msg} = QingfuShenfa.valid_damage(atk, vic, 50, %{}, two_rng())
    end

    test "random(2)!=1 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"qingfu-shenfa" => 150, "dodge" => 200})
      assert {50, nil} = QingfuShenfa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"qingfu-shenfa" => 50, "dodge" => 200})
      assert {50, nil} = QingfuShenfa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # shexing-lifan（需 skill>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.ShexingLifan

  describe "shexing-lifan valid_damage" do
    test "等级达标 -> 化解" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"shexing-lifan" => 150, "dodge" => 200})
      assert {0, _msg} = ShexingLifan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"shexing-lifan" => 50, "dodge" => 200})
      assert {50, nil} = ShexingLifan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # taiji-jian（需 skill>=100，防守方持剑）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.TaijiJian

  describe "taiji-jian valid_damage" do
    test "持剑且等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic =
        victim(
          skills: %{"taiji-jian" => 150, "parry" => 200},
          weapon: "长剑",
          weapon_skill_type: "sword"
        )

      assert {0, _msg} = TaijiJian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方无兵刃 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"taiji-jian" => 150, "parry" => 200})
      assert {50, nil} = TaijiJian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic =
        victim(
          skills: %{"taiji-jian" => 50, "parry" => 200},
          weapon: "长剑",
          weapon_skill_type: "sword"
        )

      assert {50, nil} = TaijiJian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # taiji-quan（已更新，需 skill>=100，防守方空手）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.TaijiQuan

  describe "taiji-quan valid_damage" do
    test "防守方空手且等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"taiji-quan" => 150, "parry" => 200})
      assert {0, _msg} = TaijiQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"taiji-quan" => 150, "parry" => 200}, weapon: "长剑")
      assert {50, nil} = TaijiQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"taiji-quan" => 50, "parry" => 200})
      assert {50, nil} = TaijiQuan.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # taixuan-gong（需 skill>=150，parry/force/unarmed 均映射自身，neili>=500，attacker 无兵刃，literate==0）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.TaixuanGong

  describe "taixuan-gong valid_damage" do
    test "三项均映射自身且 neili 充足 -> 化解" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic =
        victim(
          skills: %{"taixuan-gong" => 150, "force" => 100, "literate" => 0},
          neili: 500,
          mapped: %{
            "parry" => "taixuan-gong",
            "force" => "taixuan-gong",
            "unarmed" => "taixuan-gong"
          }
        )

      assert {0, _msg} = TaixuanGong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "攻击方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000, weapon: "长剑")
      vic =
        victim(
          skills: %{"taixuan-gong" => 150, "force" => 100, "literate" => 0},
          neili: 500,
          mapped: %{
            "parry" => "taixuan-gong",
            "force" => "taixuan-gong",
            "unarmed" => "taixuan-gong"
          }
        )

      assert {50, nil} = TaixuanGong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 10}, max_neili: 1000)
      vic =
        victim(
          skills: %{"taixuan-gong" => 100, "force" => 100, "literate" => 0},
          neili: 500,
          mapped: %{
            "parry" => "taixuan-gong",
            "force" => "taixuan-gong",
            "unarmed" => "taixuan-gong"
          }
        )

      assert {50, nil} = TaixuanGong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # tanzhi-shentong（需 skill>=150，victim.busy==0，finger/throwing 均映射自身，victim 无兵刃）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.TanzhiShentong

  describe "tanzhi-shentong valid_damage" do
    test "双项映射自身且空手 -> 化解" do
      atk = attacker(skills: %{"force" => 100})
      vic =
        victim(
          skills: %{"tanzhi-shentong" => 150, "parry" => 200},
          mapped: %{"finger" => "tanzhi-shentong", "throwing" => "tanzhi-shentong"}
        )

      assert {0, _msg} = TanzhiShentong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic =
        victim(
          skills: %{"tanzhi-shentong" => 150, "parry" => 200},
          weapon: "短剑",
          mapped: %{"finger" => "tanzhi-shentong", "throwing" => "tanzhi-shentong"}
        )

      assert {50, nil} = TanzhiShentong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic =
        victim(
          skills: %{"tanzhi-shentong" => 100, "parry" => 200},
          mapped: %{"finger" => "tanzhi-shentong", "throwing" => "tanzhi-shentong"}
        )

      assert {50, nil} = TanzhiShentong.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # tianluo-diwang（pilot，保留）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.TianluoDiwang

  describe "tianluo-diwang valid_damage" do
    test "等级达标且无兵刃 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"tianluo-diwang" => 150, "parry" => 100})
      assert {0, _msg} = TianluoDiwang.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方持械 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"tianluo-diwang" => 150, "parry" => 100}, weapon: "长剑")
      assert {50, nil} = TianluoDiwang.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"tianluo-diwang" => 50, "parry" => 100})
      assert {50, nil} = TianluoDiwang.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # dugu-jiujian（已更新，需 skill>=120，防守方持兵刃）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.DuguJiujian

  describe "dugu-jiujian valid_damage" do
    test "持兵刃且等级达标 -> 化解" do
      atk = attacker(skills: %{"parry" => 100, "count" => 0})
      vic = victim(skills: %{"dugu-jiujian" => 150, "parry" => 200}, weapon: "长剑")
      assert {0, _msg} = DuguJiujian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "防守方无兵刃 -> 原样返还" do
      atk = attacker(skills: %{"parry" => 100, "count" => 0})
      vic = victim(skills: %{"dugu-jiujian" => 150, "parry" => 200})
      assert {50, nil} = DuguJiujian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"parry" => 100, "count" => 0})
      vic = victim(skills: %{"dugu-jiujian" => 100, "parry" => 200}, weapon: "长剑")
      assert {50, nil} = DuguJiujian.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # wai-bagua（需 skill>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.WaiBagua

  describe "wai-bagua valid_damage" do
    test "等级达标 -> 化解" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"wai-bagua" => 150, "parry" => 200})
      assert {0, _msg} = WaiBagua.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100, "count" => 0})
      vic = victim(skills: %{"wai-bagua" => 50, "parry" => 200})
      assert {50, nil} = WaiBagua.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # xixing-dafa（需 skill>=80，attacker.jiali>=1，attacker force != taixuan-gong）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.XixingDafa

  describe "xixing-dafa valid_damage" do
    test "等级达标且 jiali>=1 -> 化解" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"xixing-dafa" => 100, "force" => 200})
      assert {0, _msg} = XixingDafa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "jiali=0 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100}, jiali: 0)
      vic = victim(skills: %{"xixing-dafa" => 100, "force" => 200})
      assert {50, nil} = XixingDafa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"xixing-dafa" => 50, "force" => 200})
      assert {50, nil} = XixingDafa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # xixing-xiaofa（需 skill>=80，attacker.jiali>=1）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.XixingXiaofa

  describe "xixing-xiaofa valid_damage" do
    test "等级达标且 jiali>=1 -> 化解" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"xixing-xiaofa" => 100, "force" => 200})
      assert {0, _msg} = XixingXiaofa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "jiali=0 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100}, jiali: 0)
      vic = victim(skills: %{"xixing-xiaofa" => 100, "force" => 200})
      assert {50, nil} = XixingXiaofa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"force" => 100})
      vic = victim(skills: %{"xixing-xiaofa" => 50, "force" => 200})
      assert {50, nil} = XixingXiaofa.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end

  # ─────────────────────────────
  # zhuangzi-wu（需 skill>=100）
  # ─────────────────────────────
  alias Kantele.Combat.Skills.ZhuangziWu

  describe "zhuangzi-wu valid_damage" do
    test "等级达标 -> 化解" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"zhuangzi-wu" => 150, "dodge" => 200})
      assert {0, _msg} = ZhuangziWu.valid_damage(atk, vic, 50, %{}, zero_rng())
    end

    test "等级不足 -> 原样返还" do
      atk = attacker(skills: %{"dodge" => 100, "count" => 0})
      vic = victim(skills: %{"zhuangzi-wu" => 50, "dodge" => 200})
      assert {50, nil} = ZhuangziWu.valid_damage(atk, vic, 50, %{}, zero_rng())
    end
  end
end
