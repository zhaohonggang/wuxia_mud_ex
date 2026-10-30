defmodule Kantele.Combat.SkillsUltimateTest do
  @moduledoc """
  「极意」动态末式 + 独孤九剑无招表（C 相位第二批）

  LPC 里少数技能的 `action` 表最后一式不是字面量，而是
  `this_player()->query_skill(...)/k + random(...)`；`translate_skill.exs`
  只能抽静态字面量，这些式子就被丢掉了（表长少 1）。本测试锁定：

  1. 三张表（华山剑法 6+1 / 太极拳 30+1 / 抽髓掌 5+1）的条数与 `lvl` 门槛；
  2. `query_action/3` 只在 `level > 极意.lvl` 时才把动态式并入候选；
  3. 五项数值按 LPC 公式（`div(skill, k) + random(div(skill, k'))`）生成；
  4. **太极拳的回归**：旧实现是 `if level >= 350, do: @ultimate`（到级必出），
     LPC 其实是把极意当成表内一项、由 `NewRandom` 与其他招式一起抽 —— 已修正；
  5. `dugu-jiujian` 的 `action2`（无招表，3 式）按 `can_learn/dugu-jiujian/nothing`
     切换，且是**均匀** `random(sizeof())`，不按 `lvl` 过滤、不用 `NewRandom`；
  6. `dugu-jiujian` 的 `valid_enable/2` 语义（LPC 读 `this_player()` 等级 >= 30）。

  `rng` 约定：返回 `1..n`（`&:rand.uniform/1`），`Skill.lpc_random/2` 内部减一。
  所以 `fn _ -> 1 end` ⇒ `random(n) == 0`；`fn _ -> 15 end` ⇒ `random(n) == 14`。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skill
  alias Kantele.Combat.Skills.ChousuiZhang
  alias Kantele.Combat.Skills.DuguJiujian
  alias Kantele.Combat.Skills.HuashanJian
  alias Kantele.Combat.Skills.TaijiQuan

  # pick_action_with_ultimate 用的样例表
  @sample_static [%{"action" => "一式", "lvl" => 0}, %{"action" => "二式", "lvl" => 0}]
  @sample_ultimate %{"action" => "极意", "lvl" => 100, "skill_name" => "极意"}

  # random(n) == 0：数值取整除项；NewRandom 落 n-6（靠前的招式）
  defp lo, do: fn _ -> 1 end

  # random(n) == min(n,15)-1：对 n>=15 永远取 14（NewRandom 选表尾）；对 n<15 取 n-1（合法最大）
  defp hi, do: fn n -> min(n, 15) end

  # 计数 rng（进程字典，测试进程内隔离），恒返回 1
  defp counting_rng do
    fn _n ->
      Process.put(:rng_calls, Process.get(:rng_calls, 0) + 1)
      1
    end
  end

  defp reset_calls, do: Process.put(:rng_calls, 0)
  defp calls, do: Process.get(:rng_calls, 0)

  # 每次调用消耗 5 次 rng，模拟真实 ultimate_values
  defp five_values do
    fn _attacker, rng ->
      for i <- 1..5, into: %{}, do: {"k#{i}-#{Skill.lpc_random(rng, 10)}", 1}
    end
  end

  defp fighter(skills) do
    %Fighter{skills: skills, mapped: %{}, weapon_name: nil, weapon_skill_type: nil}
  end

  defp character(skills) do
    stats = struct(Stats.new(), skills: skills)

    %Kalevala.Character{
      id: "player-1",
      name: "石破天",
      meta: %Kantele.Character.PlayerMeta{
        stats: stats,
        marks: %{},
        combat: %Kantele.Character.Combat{}
      }
    }
  end

  describe "Skill.lpc_random/2（LPC random(n) 语义）" do
    test "n <= 0 恒为 0，不消耗 rng" do
      boom = fn _ -> flunk("n <= 0 不应调用 rng") end

      assert Skill.lpc_random(boom, 0) == 0
      assert Skill.lpc_random(boom, -5) == 0
    end

    test "n > 0 时返回 rng.(n) - 1" do
      assert Skill.lpc_random(fn _ -> 1 end, 10) == 0
      assert Skill.lpc_random(fn _ -> 10 end, 10) == 9
      assert Skill.lpc_random(fn n -> div(n, 2) end, 10) == 4
    end
  end

  describe "Skill.skill_of/2（Fighter 与角色两种形状）" do
    test "Fighter 走 skills 映射" do
      assert Skill.skill_of(fighter(%{"force" => 120}), "force") == 120
      assert Skill.skill_of(fighter(%{"force" => 120}), "sword") == 0
    end

    test "角色走 meta.stats" do
      assert Skill.skill_of(character(%{"force" => 80}), "force") == 80
    end

    test "未知形状 / nil 一律 0" do
      assert Skill.skill_of(nil, "force") == 0
      assert Skill.skill_of(%{}, "force") == 0
    end
  end

  describe "Skill.pick_action_with_ultimate/6" do
    test "level <= lvl 时不生成动态式（只消耗选招那 1 次 rng）" do
      reset_calls()

      for level <- [0, 50, 100] do
        action =
          Skill.pick_action_with_ultimate(
            @sample_static,
            level,
            nil,
            @sample_ultimate,
            five_values(),
            counting_rng()
          )

        assert action in @sample_static
      end

      # 3 次调用：level=0 时 count=0 走 List.first（不消耗 rng），level=50/100 各消耗 1 次
      assert calls() == 2
    end

    test "level > lvl 时并入候选（多消耗 5 次生成数值）" do
      reset_calls()

      action =
        Skill.pick_action_with_ultimate(
          @sample_static,
          101,
          nil,
          @sample_ultimate,
          five_values(),
          counting_rng()
        )

      # 5 次数值 + 1 次选招
      assert calls() == 6
      assert is_map(action)
      assert action["lvl"] in [0, 100]
    end

    test "并入后可被抽中（表尾）" do
      values = fn _attacker, _rng -> %{"force" => 999} end
      # count = 3 → NewRandom 在 remaining=14 时落 n-1 = 2 → 表尾（极意）
      action = Skill.pick_action_with_ultimate(@sample_static, 101, nil, @sample_ultimate, values, hi())

      assert action["skill_name"] == "极意"
      assert action["force"] == 999
    end
  end

  describe "华山剑法（6 静态 + 第 7 式极意 lvl 200）" do
    test "表长与极意门槛" do
      assert length(HuashanJian.actions()) == 6
      assert HuashanJian.ultimate()["lvl"] == 200
      assert HuashanJian.ultimate()["skill_name"] == "极意"
    end

    test "level 200 及以下抽不到极意（LPC 是 level > lvl）" do
      attacker = fighter(%{"force" => 100, "sword" => 100})

      for level <- [0, 100, 199, 200] do
        action = HuashanJian.query_action(level, hi(), attacker)
        assert action["skill_name"] != "极意"
      end
    end

    test "level 201+ 可抽到极意，五项数值按 LPC 公式" do
      attacker = fighter(%{"force" => 100, "sword" => 100, "dodge" => 100, "parry" => 100})
      action = HuashanJian.query_action(300, hi(), attacker)

      assert action["skill_name"] == "极意"
      # random(n) == 14
      assert action["force"] == div(100, 2) + 14
      assert action["attack"] == div(100, 4) + 14
      assert action["dodge"] == div(100, 6) + 14
      assert action["parry"] == div(100, 6) + 14
      assert action["damage"] == div(100, 4) + 14
      assert action["damage_type"] == "刺伤"
    end

    test "random(n) == 0 时数值取整除项" do
      attacker = fighter(%{"force" => 100, "sword" => 100, "dodge" => 100, "parry" => 100})
      # lo 的 NewRandom 落 index 1（靠前），抽到的是静态式
      action = HuashanJian.query_action(300, lo(), attacker)

      refute action["skill_name"] == "极意"
      assert action in HuashanJian.actions()
    end

    test "query_skill_name 含极意（LPC 遍历整表）" do
      assert HuashanJian.query_skill_name(199) == "白虹贯日"
      assert HuashanJian.query_skill_name(200) == "极意"
      assert HuashanJian.query_skill_name(300) == "极意"
    end

    test "query_action/2（无角色）只用静态 6 式" do
      for _ <- 1..20 do
        action = HuashanJian.query_action(500, hi())
        assert action in HuashanJian.actions()
      end
    end
  end

  describe "太极拳（30 静态 + 末式极意 lvl 350）" do
    test "表长与极意门槛" do
      assert length(TaijiQuan.actions()) == 30
      assert TaijiQuan.ultimate()["lvl"] == 350
    end

    test "回归：到 350 级不再「必出极意」" do
      attacker = fighter(%{"force" => 100, "unarmed" => 100})

      # lo ⇒ NewRandom 落 n-6 = 25，是静态招式
      action = TaijiQuan.query_action(400, lo(), attacker)
      assert action["skill_name"] != "极意"
      assert action in TaijiQuan.actions()
    end

    test "level 350 及以下抽不到极意" do
      attacker = fighter(%{"force" => 100, "unarmed" => 100})

      for level <- [0, 250, 349, 350] do
        assert TaijiQuan.query_action(level, hi(), attacker)["skill_name"] != "极意"
      end
    end

    test "level 351+ 可抽到极意，五项数值按 LPC 公式" do
      attacker = fighter(%{"force" => 100, "unarmed" => 100, "dodge" => 100, "parry" => 100})
      action = TaijiQuan.query_action(400, hi(), attacker)

      assert action["skill_name"] == "极意"
      assert action["force"] == div(100, 4) + 14
      assert action["attack"] == div(100, 5) + 14
      assert action["dodge"] == div(100, 4) + 14
      assert action["parry"] == div(100, 3) + 14
      assert action["damage"] == div(100, 4) + 14
    end

    test "query_skill_name 含极意" do
      assert TaijiQuan.query_skill_name(349) == "如封似闭"
      assert TaijiQuan.query_skill_name(350) == "极意"
    end
  end

  describe "抽髓掌（5 静态 + 第 6 式极意 lvl 200）" do
    test "表长与极意门槛" do
      assert length(ChousuiZhang.actions()) == 5
      assert ChousuiZhang.ultimate()["lvl"] == 200
    end

    test "level 200 及以下抽不到极意；201+ 可抽到" do
      attacker = fighter(%{"force" => 100, "strike" => 100})

      for level <- [0, 100, 200] do
        assert ChousuiZhang.query_action(level, hi(), attacker)["skill_name"] != "极意"
      end

      assert ChousuiZhang.query_action(201, hi(), attacker)["skill_name"] == "极意"
    end

    test "五项数值按 LPC 公式" do
      attacker = fighter(%{"force" => 100, "strike" => 100, "dodge" => 100, "parry" => 100})
      action = ChousuiZhang.query_action(300, hi(), attacker)

      assert action["force"] == div(100, 2) + 14
      assert action["attack"] == div(100, 4) + 14
      assert action["dodge"] == div(100, 6) + 14
      assert action["parry"] == div(100, 6) + 14
      assert action["damage"] == div(100, 4) + 14
      assert action["damage_type"] == "瘀伤"
    end
  end

  describe "独孤九剑（action 24 式 / action2 无招 3 式）" do
    test "无标记 → action 表（首式 force 290）" do
      action = DuguJiujian.query_action(100, lo(), fighter(%{}))

      assert action["force"] == 290
      assert action["damage"] == 160
    end

    test "有 can_learn/dugu-jiujian/nothing 标记 → action2 表（首式 force 600）" do
      attacker = %Fighter{skills: %{}, marks: %{"can_learn/dugu-jiujian/nothing" => 1}}
      action = DuguJiujian.query_action(100, lo(), attacker)

      assert action["force"] == 600
      assert action["damage"] == 460
      assert action["attack"] == 300
    end

    test "均匀抽取，不按 lvl 过滤（LPC random(sizeof())）" do
      attacker = %Fighter{skills: %{}, marks: %{"can_learn/dugu-jiujian/nothing" => 1}}

      # rng 1..3 覆盖 action2 全部三式
      for n <- 1..3 do
        action = DuguJiujian.query_action(0, fn _ -> n end, attacker)
        assert action["force"] == 600
      end
    end

    test "valid_enable/1 保守分支：仅 parry" do
      assert DuguJiujian.valid_enable("parry")
      refute DuguJiujian.valid_enable("sword")
    end

    test "valid_enable/2：等级 >= 30 才可 sword（LPC this_player 分支）" do
      low = character(%{"dugu-jiujian" => 29})
      high = character(%{"dugu-jiujian" => 30})

      refute DuguJiujian.valid_enable("sword", low)
      assert DuguJiujian.valid_enable("sword", high)

      assert DuguJiujian.valid_enable("parry", low)
      assert DuguJiujian.valid_enable("parry", high)
    end

    test "回归：valid_enable/2 收到角色时不得因项序比较而误判为真" do
      # Erlang 项序里 struct > 任何整数，旧的 `level >= 30` 会恒真
      empty = character(%{})

      refute DuguJiujian.valid_enable("sword", empty)
      refute DuguJiujian.valid_enable("blade", empty)
    end
  end

  describe "Fighter.marks（LPC me->query(\"can_learn/...\")）" do
    test "from_character 带出 meta.marks" do
      stats = struct(Stats.new(), skills: %{})
      marks = %{"can_learn/dugu-jiujian/nothing" => 1}

      char = %Kalevala.Character{
        id: "player-1",
        name: "石破天",
        meta: %Kantele.Character.PlayerMeta{
          stats: stats,
          marks: marks,
          combat: %Kantele.Character.Combat{},
          vitals: %Kantele.Character.Vitals{}
        }
      }

      f = Fighter.from_character(char)

      assert f.marks == marks
      assert Skill.mark?(f, "can_learn/dugu-jiujian/nothing")
      refute Skill.mark?(f, "can_learn/other")
    end

    test "Fighter.new/0 默认空 marks" do
      assert Fighter.new().marks == %{}
      refute Skill.mark?(Fighter.new(), "anything")
    end

    test "mark? 仍支持角色形状（meta.marks）" do
      char = character(%{})

      refute Skill.mark?(char, "can_learn/dugu-jiujian/nothing")
      assert Skill.mark?(%{char | meta: %{char.meta | marks: %{"k" => 1}}}, "k")
    end
  end

  describe "Engine.select_action/1 走 query_action/3" do
    test "太极拳到级不再恒出极意（端到端）" do
      attacker = %Fighter{
        attack_skill: "unarmed",
        mapped: %{"unarmed" => "taiji-quan"},
        skills: %{"taiji-quan" => 400, "unarmed" => 400, "force" => 400},
        weapon_name: nil
      }

      names = for _ <- 1..200, do: Kantele.Combat.Engine.select_action(attacker)["skill_name"]
      taiji = Enum.count(names, &(&1 == "极意"))

      assert taiji > 0, "400 级太极拳应当能抽出极意"
      assert taiji < 200, "极意是表内一项，不应每次都出"
    end

    test "独孤九剑带 nothing 标记时走无招表（端到端）" do
      attacker = %Fighter{
        attack_skill: "sword",
        mapped: %{"sword" => "dugu-jiujian"},
        skills: %{"dugu-jiujian" => 200, "sword" => 200},
        weapon_name: "剑",
        weapon_skill_type: "sword",
        marks: %{"can_learn/dugu-jiujian/nothing" => 1}
      }

      for _ <- 1..30 do
        assert Kantele.Combat.Engine.select_action(attacker)["force"] == 600
      end
    end
  end
end
