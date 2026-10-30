defmodule Kantele.Combat.SkillsActionfTest do
  @moduledoc """
  6 个「绝学内功」的双招式表迁移（`actionf` / `actionw` / `actionbad`）。

  LPC 里这 6 个 `inherit FORCE` 的技能用 `mapping *actionf` 而不是 `action`，
  `translate_skill.exs` 只认 `action`，生成时整表丢失 → 出招无描述无伤害。
  本测试锁定：表长、持械/空手分流、`pick_action_for` 回落、`valid_enable`
  的三类分支（直接列 / reborn 门控 / literate 全拒 + enable_weapon）。

  两张表在 6 个技能里都**无重叠**（脚本已核对），所以可用「属于 A 且不属于 B」
  来断言分流正确。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skill
  alias Kantele.Combat.Skills.BlueseaForce
  alias Kantele.Combat.Skills.JiuyangShengong
  alias Kantele.Combat.Skills.JiuyinShengong
  alias Kantele.Combat.Skills.KuihuaMogong
  alias Kantele.Combat.Skills.TaixuanGong
  alias Kantele.Combat.Skills.ZhonghuaAojue

  # 全 6 个技能及其 LPC 表长（actionf / actionw / actionbad）
  @skills [
    {BlueseaForce, "bluesea-force", 6, 6, 0},
    {JiuyangShengong, "jiuyang-shengong", 6, 5, 0},
    {JiuyinShengong, "jiuyin-shengong", 6, 5, 0},
    {KuihuaMogong, "kuihua-mogong", 6, 6, 0},
    {TaixuanGong, "taixuan-gong", 6, 5, 1},
    {ZhonghuaAojue, "zhonghua-aojue", 6, 6, 0}
  ]

  # 固定 rng：NewRandom 收到 rand=1 时总取最靠后的可用招式，便于断言
  defp rng, do: fn _ -> 1 end

  defp weapon(name), do: %Fighter{weapon_name: name}

  defp character(opts \\ []) do
    stats =
      Stats.new()
      |> struct(
        reborn: Keyword.get(opts, :reborn, %{str: 0, int: 0, con: 0, dex: 0}),
        skills: Keyword.get(opts, :skills, %{})
      )

    %Kalevala.Character{
      id: "player-1",
      name: "石破天",
      meta: %Kantele.Character.PlayerMeta{
        stats: stats,
        marks: Keyword.get(opts, :marks, %{})
      }
    }
  end

  describe "never-defeated（action_default / action_whip，按武器 skill_type 分表）" do
    alias Kantele.Combat.Skills.NeverDefeated

    test "表长：action_default=11 action_whip=5，且已进注册表" do
      assert length(NeverDefeated.actions()) == 11
      assert length(NeverDefeated.weapon_actions()) == 5
      assert Kantele.Combat.Skills.get("never-defeated") == NeverDefeated
    end

    test "valid_enable：11 项全开（含 dagger/throwing）" do
      for usage <-
            ~w(sword blade dagger staff hammer club whip dodge parry force throwing) do
        assert NeverDefeated.valid_enable(usage), "应允许 #{usage}"
      end

      refute NeverDefeated.valid_enable("unarmed")
      refute NeverDefeated.valid_enable("finger")
    end

    test "鞭类武器 → action_whip；其余武器/空手 → action_default" do
      whip = %Fighter{weapon_name: "长鞭", weapon_skill_type: "whip"}
      sword = %Fighter{weapon_name: "长剑", weapon_skill_type: "sword"}
      bare = %Fighter{weapon_name: nil, weapon_skill_type: nil}

      assert NeverDefeated.query_action(10, rng(), whip) in NeverDefeated.weapon_actions()
      assert NeverDefeated.query_action(10, rng(), sword) in NeverDefeated.actions()
      assert NeverDefeated.query_action(10, rng(), bare) in NeverDefeated.actions()
    end

    test "持械但 skill_type 不是 whip（如剑）仍走 action_default —— 不是「有武器就换表」" do
      sword = %Fighter{weapon_name: "长剑", weapon_skill_type: "sword"}
      action = NeverDefeated.query_action(10, rng(), sword)

      refute action in NeverDefeated.weapon_actions()
    end
  end

  describe "Skill.weapon_skill_type/1" do
    test "取原始 skill_type，空手为 nil" do
      assert Skill.weapon_skill_type(%Fighter{weapon_skill_type: "whip"}) == "whip"
      assert Skill.weapon_skill_type(%Fighter{weapon_skill_type: nil}) == nil
      assert Skill.weapon_skill_type(%Fighter{}) == nil
      assert Skill.weapon_skill_type(nil) == nil
    end
  end

  describe "注册表（这 6 个之前既没进 @static，招式表也丢了）" do
    for {module, id, _f, _w, _bad} <- @skills do
      test "#{id} 可从 Skills.get/1 解析，且 enable 不再报「没有这项武功」" do
        module = unquote(module)

        assert Kantele.Combat.Skills.get(unquote(id)) == module
        assert Kantele.Combat.Skills.known?(unquote(id))
        # valid_enable 至少放开 force，否则 enable 永远失败
        assert module.valid_enable("force")
      end
    end
  end

  describe "招式表长度（对照 LPC actionf/actionw/actionbad）" do
    for {module, id, f, w, bad} <- @skills do
      test "#{id}：actionf=#{f} actionw=#{w} actionbad=#{bad}" do
        module = unquote(module)

        assert length(module.actions()) == unquote(f)
        assert length(module.weapon_actions()) == unquote(w)

        if unquote(bad) > 0 do
          assert function_exported?(module, :query_action, 3)
        end

        # 每式都必须带动作文案与伤害类型，否则出招会掉字
        for action <- module.actions() ++ module.weapon_actions() do
          assert is_binary(action["action"]) and action["action"] != ""
          assert is_binary(action["damage_type"])
          assert is_integer(action["damage"])
        end
      end
    end
  end

  describe "持械 / 空手分流（LPC weapon ? actionw : actionf）" do
    for {module, id, _f, _w, _bad} <- @skills do
      test "#{id}：持械取 weapon_actions，空手取 actions" do
        module = unquote(module)

        armed = module.query_action(10, rng(), weapon("长剑"))
        unarmed = module.query_action(10, rng(), weapon(nil))

        assert armed in module.weapon_actions()
        refute armed in module.actions()

        assert unarmed in module.actions()
        refute unarmed in module.weapon_actions()
      end
    end

    test "query_action/2（无角色上下文）按空手表选" do
      action = BlueseaForce.query_action(10, rng())

      assert action in BlueseaForce.actions()
      refute action in BlueseaForce.weapon_actions()
    end

    test "weapon_name 为空串也视为空手（LPC 无 weapon 对象）" do
      action = BlueseaForce.query_action(10, rng(), weapon(""))

      assert action in BlueseaForce.actions()
    end
  end

  describe "Skill.pick_action_for/5 回落" do
    test "持械但武器表为空 → 回落到空手表（半迁移技能不会出空招）" do
      actions = [%{"action" => "一拳", "lvl" => 0, "damage" => 1}]

      action = Skill.pick_action_for(actions, [], 10, weapon("长剑"), rng())

      assert action["action"] == "一拳"
    end

    test "空手时即便武器表非空也走空手表" do
      actions = [%{"action" => "一拳", "lvl" => 0}]
      weapon_actions = [%{"action" => "一剑", "lvl" => 0}]

      assert Skill.pick_action_for(actions, weapon_actions, 10, weapon(nil), rng())["action"] == "一拳"
    end

    test "持械且武器表非空 → 走武器表" do
      actions = [%{"action" => "一拳", "lvl" => 0}]
      weapon_actions = [%{"action" => "一剑", "lvl" => 0}]

      assert Skill.pick_action_for(actions, weapon_actions, 10, weapon("长剑"), rng())["action"] ==
               "一剑"
    end
  end

  describe "Skill.weapon?/1" do
    test "非空字符串为持械" do
      assert Skill.weapon?(%{weapon_name: "长剑"})
      refute Skill.weapon?(%{weapon_name: nil})
      refute Skill.weapon?(%{weapon_name: ""})
      refute Skill.weapon?(%{})
      refute Skill.weapon?(nil)
    end
  end

  describe "Skill.reborn?/1（LPC me->query(\"reborn\")）" do
    test "reborn 加成全 0 → 未转世" do
      refute Skill.reborn?(character())
    end

    test "reborn 任一加成非 0 → 已转世" do
      assert Skill.reborn?(character(reborn: %{str: 5, int: 0, con: 0, dex: 0}))
    end

    test "reborn 为整数时按 > 0 判定" do
      assert Skill.reborn?(character(reborn: 3))
      refute Skill.reborn?(character(reborn: 0))
    end

    test "非角色结构 → false" do
      refute Skill.reborn?(nil)
      refute Skill.reborn?(%{})
    end
  end

  describe "Skill.mark?/2（LPC me->query(\"can_learn/...\")）" do
    test "marks 里有非零值 → true" do
      assert Skill.mark?(character(marks: %{"can_learn/x/enable_weapon" => 1}), "can_learn/x/enable_weapon")
    end

    test "缺键 / 0 / false → false" do
      refute Skill.mark?(character(), "can_learn/x/enable_weapon")
      refute Skill.mark?(character(marks: %{"k" => 0}), "k")
      refute Skill.mark?(character(marks: %{"k" => false}), "k")
    end
  end

  describe "valid_enable/1（无角色上下文，走保守分支）" do
    test "bluesea-force：指法/掌法/杖法/轻功/招架/内功" do
      for usage <- ~w(finger strike staff dodge parry force) do
        assert BlueseaForce.valid_enable(usage), "应允许 #{usage}"
      end

      for usage <- ~w(sword blade unarmed throwing whip) do
        refute BlueseaForce.valid_enable(usage), "不应允许 #{usage}"
      end
    end

    test "kuihua-mogong：拳脚/剑/轻功/招架/内功" do
      for usage <- ~w(unarmed sword dodge parry force) do
        assert KuihuaMogong.valid_enable(usage)
      end

      refute KuihuaMogong.valid_enable("blade")
      refute KuihuaMogong.valid_enable("staff")
    end

    test "zhonghua-aojue：拳脚/掌法/剑/轻功/招架/内功" do
      for usage <- ~w(unarmed strike sword dodge parry force) do
        assert ZhonghuaAojue.valid_enable(usage)
      end

      refute ZhonghuaAojue.valid_enable("blade")
      refute ZhonghuaAojue.valid_enable("whip")
    end

    test "jiuyang / jiuyin：未转世保守分支只有 force" do
      assert JiuyangShengong.valid_enable("force")
      refute JiuyangShengong.valid_enable("unarmed")
      refute JiuyangShengong.valid_enable("sword")

      assert JiuyinShengong.valid_enable("force")
      refute JiuyinShengong.valid_enable("claw")
    end

    test "taixuan：未拿到 enable_weapon 时只放开基础四项" do
      for usage <- ~w(force unarmed dodge parry) do
        assert TaixuanGong.valid_enable(usage)
      end

      refute TaixuanGong.valid_enable("sword")
      refute TaixuanGong.valid_enable("blade")
    end
  end

  describe "jiuyang-shengong valid_enable/2（reborn + enable_weapon 双层门控）" do
    @enable_weapon "can_learn/jiuyang-shengong/enable_weapon"

    test "未转世：只有 force" do
      c = character()

      assert JiuyangShengong.valid_enable("force", c)
      refute JiuyangShengong.valid_enable("unarmed", c)
      refute JiuyangShengong.valid_enable("sword", c)
    end

    test "已转世未拿 enable_weapon：force/unarmed/parry" do
      c = character(reborn: %{str: 1, int: 0, con: 0, dex: 0})

      for usage <- ~w(force unarmed parry) do
        assert JiuyangShengong.valid_enable(usage, c)
      end

      refute JiuyangShengong.valid_enable("sword", c)
      refute JiuyangShengong.valid_enable("blade", c)
    end

    test "已转世且拿到 enable_weapon：再加 sword/blade" do
      c = character(reborn: %{str: 1, int: 0, con: 0, dex: 0}, marks: %{@enable_weapon => 1})

      for usage <- ~w(force unarmed parry sword blade) do
        assert JiuyangShengong.valid_enable(usage, c)
      end

      refute JiuyangShengong.valid_enable("staff", c)
    end
  end

  describe "jiuyin-shengong valid_enable/2（reborn 门控）" do
    test "未转世：只有 force（usage_skills3）" do
      c = character()

      assert JiuyinShengong.valid_enable("force", c)

      for usage <- ~w(unarmed strike claw hand cuff dodge whip parry) do
        refute JiuyinShengong.valid_enable(usage, c)
      end
    end

    test "已转世：放开 usage_skills 九项" do
      c = character(reborn: %{dex: 2})

      for usage <- ~w(unarmed strike claw hand cuff dodge whip parry force) do
        assert JiuyinShengong.valid_enable(usage, c)
      end

      refute JiuyinShengong.valid_enable("sword", c)
    end
  end

  describe "taixuan-gong valid_enable/2（literate 全拒 + 剑刀等级）" do
    @enable_weapon "can_learned/taixuan-gong/enable_weapon"

    test "识字 → 一项都不能 enable（LPC usage == 0 恒假）" do
      c = character(skills: %{"literate" => 10}, marks: %{@enable_weapon => 1})

      for usage <- ~w(force unarmed dodge parry sword blade) do
        refute TaixuanGong.valid_enable(usage, c)
      end
    end

    test "不识字且未拿 enable_weapon：基础四项" do
      c = character()

      for usage <- ~w(force unarmed dodge parry) do
        assert TaixuanGong.valid_enable(usage, c)
      end

      refute TaixuanGong.valid_enable("sword", c)
      refute TaixuanGong.valid_enable("blade", c)
    end

    test "enable_weapon + 剑刀都低于太玄：仍只有基础四项" do
      c =
        character(
          skills: %{"taixuan-gong" => 100, "sword" => 50, "blade" => 50},
          marks: %{@enable_weapon => 1}
        )

      refute TaixuanGong.valid_enable("sword", c)
      refute TaixuanGong.valid_enable("blade", c)
    end

    test "enable_weapon + 剑低于、刀高于太玄：放开刀" do
      c =
        character(
          skills: %{"taixuan-gong" => 100, "sword" => 50, "blade" => 150},
          marks: %{@enable_weapon => 1}
        )

      assert TaixuanGong.valid_enable("blade", c)
      refute TaixuanGong.valid_enable("sword", c)
    end

    test "enable_weapon + 剑高于、刀低于太玄：放开剑" do
      c =
        character(
          skills: %{"taixuan-gong" => 100, "sword" => 150, "blade" => 50},
          marks: %{@enable_weapon => 1}
        )

      assert TaixuanGong.valid_enable("sword", c)
      refute TaixuanGong.valid_enable("blade", c)
    end

    test "enable_weapon + 剑刀都高于太玄：剑刀都放开" do
      c =
        character(
          skills: %{"taixuan-gong" => 100, "sword" => 150, "blade" => 150},
          marks: %{@enable_weapon => 1}
        )

      assert TaixuanGong.valid_enable("sword", c)
      assert TaixuanGong.valid_enable("blade", c)
    end
  end

  describe "taixuan-gong query_action/3（literate 走 actionbad[0]）" do
    test "识字 → 恒为「胡乱使出」那一式" do
      bad = TaixuanGong.query_action(10, rng(), %Fighter{skills: %{"literate" => 1}})

      assert bad["action"] =~ "胡乱使出"
      assert bad["damage"] == 10

      # 再抽几次都一样（LPC 直接 return actionbad[0]，不随机）
      for _ <- 1..5 do
        assert TaixuanGong.query_action(10, rng(), %Fighter{skills: %{"literate" => 1}}) == bad
      end
    end

    test "不识字 → 正常按持械分流" do
      armed = TaixuanGong.query_action(10, rng(), %Fighter{skills: %{}, weapon_name: "长剑"})
      unarmed = TaixuanGong.query_action(10, rng(), %Fighter{skills: %{}, weapon_name: nil})

      assert armed in TaixuanGong.weapon_actions()
      assert unarmed in TaixuanGong.actions()
      refute unarmed["action"] =~ "胡乱使出"
    end
  end

  describe "Engine.select_action/1 把攻击方快照传下去" do
    alias Kantele.Combat.Engine

    test "持械 → 用 weapon_actions" do
      fighter = %Fighter{
        attack_skill: "force",
        mapped: %{"force" => "bluesea-force"},
        skills: %{"bluesea-force" => 50},
        weapon_name: "长剑"
      }

      action = Engine.select_action(fighter)

      assert action in BlueseaForce.weapon_actions()
      refute action in BlueseaForce.actions()
    end

    test "空手 → 用 actions" do
      fighter = %Fighter{
        attack_skill: "force",
        mapped: %{"force" => "bluesea-force"},
        skills: %{"bluesea-force" => 50},
        weapon_name: nil
      }

      action = Engine.select_action(fighter)

      assert action in BlueseaForce.actions()
    end

    test "never-defeated 持鞭 → 用 action_whip（按 weapon_skill_type 分表）" do
      fighter = %Fighter{
        attack_skill: "whip",
        mapped: %{"whip" => "never-defeated"},
        skills: %{"never-defeated" => 50},
        weapon_name: "长鞭",
        weapon_skill_type: "whip"
      }

      action = Engine.select_action(fighter)

      assert action in Kantele.Combat.Skills.NeverDefeated.weapon_actions()
    end

    test "from_character 把武器的原始 skill_type 带进快照" do
      c = %Kalevala.Character{
        id: "player-1",
        name: "石破天",
        meta: %Kantele.Character.PlayerMeta{
          stats: Stats.new(),
          vitals: Kantele.Character.Vitals.new(),
          combat: %Kantele.Character.Combat{
            Kantele.Character.Combat.new()
            | equipped: %{weapon: %{name: "长鞭", skill_type: "whip"}}
          }
        }
      }

      fighter = Fighter.from_character(c)

      assert fighter.weapon_name == "长鞭"
      assert fighter.weapon_skill_type == "whip"
    end
  end
end
