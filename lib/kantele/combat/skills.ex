defmodule Kantele.Combat.Skills do
  @moduledoc """
  武学注册表：技能 id -> 实现 module

  注册表=静态内建 `@skills` + 运行时增量（`:persistent_term`）。运行时可
  `register/2` 追加（测试注入新技能、启动时挂载更多武学），`unregister/1` 移除。
  """

  @static %{
    "liuxin-jian" => Kantele.Combat.Skills.LiuxinJian,
    "liuxi-neigong" => Kantele.Combat.Skills.LiuxiNeigong,
    "taiji-quan" => Kantele.Combat.Skills.TaijiQuan,
    "dugu-jiujian" => Kantele.Combat.Skills.DuguJiujian
  }

  @doc "运行时注册一门武学（覆盖同名内建）"
  def register(id, module) when is_binary(id) and is_atom(module) do
    :persistent_term.put({__MODULE__, :extra}, Map.put(extras(), id, module))
    :ok
  end

  @doc "运行时移除一门武学（仅影响运行时增量，不碰内建）"
  def unregister(id) when is_binary(id) do
    :persistent_term.put({__MODULE__, :extra}, Map.delete(extras(), id))
    :ok
  end

  def all(), do: Map.merge(@static, extras())

  def get(id) when is_binary(id), do: Map.get(all(), id)
  def get(_id), do: nil

  def known?(id), do: Map.has_key?(all(), id)

  @doc """
  按用法解析可 enable 的特技（对应 valid_enable）

  玩家 map_skill 之后，攻击/招架/内功都会映射到特技模块
  """
  def enabled_for(stats, usage) do
    case Kantele.Character.Stats.mapped(stats, usage) do
      nil -> nil
      skill_id -> get(skill_id)
    end
  end

  @doc """
  技能力量 / 武学上限（对应 `feature/sadjust.c` 的 `skill_adjust`）

  LPC: `lmt = combat_exp^3 / 10`，把超过上限的 martial 类技能压回 `lmt`。
  返回压制后的 skills 映射。`martial_keys` 为判定"martial 类"的技能名集合，
  调用方提供（由技能元数据决定）。
  """
  def skill_adjust(skills, combat_exp, martial_keys \\ :auto) when is_map(skills) do
    lmt = div(combat_exp * combat_exp * combat_exp, 10)
    selected = if martial_keys == :auto, do: Map.keys(skills), else: martial_keys

    Enum.reduce(selected, skills, fn name, acc ->
      if Map.get(acc, name, 0) > lmt do
        Map.put(acc, name, lmt)
      else
        acc
      end
    end)
  end

  @doc """
  死亡技能惩罚（对应 `feature/skill.c skill_death_penalty`）

  无 `learned` 映射：每技能 -1，跌破 1 删除。
  有 `learned` 映射（`%{技能 => 领悟点数}`）：若 `learned[sk] > (skills[sk]+1)^2/2`
  则删 learned[sk]，否则 skills[sk]--，跌破 0 删除。
  返回 `{skills_after, learned_after}`。
  """
  def skill_death_penalty(skills, learned \\ %{})

  def skill_death_penalty(skills, learned) when map_size(learned) == 0 do
    skills =
      Enum.reduce(skills, %{}, fn {name, lvl}, acc ->
        if lvl - 1 < 1, do: acc, else: Map.put(acc, name, lvl - 1)
      end)

    {skills, %{}}
  end

  def skill_death_penalty(skills, learned) do
    {skills, learned} =
      Enum.reduce(skills, {skills, learned}, fn {name, lvl}, {sk_acc, ln_acc} ->
        learned_lvl = Map.get(ln_acc, name, 0)

        if learned_lvl > div((lvl + 1) * (lvl + 1), 2) do
          {sk_acc, Map.delete(ln_acc, name)}
        else
          new_lvl = if lvl - 1 < 0, do: nil, else: lvl - 1
          sk_acc = if new_lvl, do: Map.put(sk_acc, name, new_lvl), else: Map.delete(sk_acc, name)
          {sk_acc, ln_acc}
        end
      end)

    {skills, learned}
  end

  @doc """
  逐出师门技能惩罚（对应 `feature/skill.c skill_expell_penalty`）

  - 技能文件不存在（`missing?/1` 谓词）→ 删除该技能
  - 非 martial 类或 `martial-cognize` → 保留
  - 可 enable parry/dodge/throwing/force（`guard_special?/1` 谓词）→ 删除
  - 其余 >100 压回 100
  `meta` 由调用方提供（按技能名查 type / valid_enable），形如
  `%{name => %{type: "martial", guards: ["parry"]}}`。
  """
  def skill_expell_penalty(skills, meta) when is_map(skills) do
    {done, _} =
      Enum.reduce(skills, {%{}, meta}, fn {name, lvl}, {acc, m} ->
        rel = Map.get(m, name, %{})

        cond do
          Map.get(rel, :missing, false) ->
            {acc, m}

          Map.get(rel, :type) != "martial" or name == "martial-cognize" ->
            {Map.put(acc, name, lvl), m}

          guards_special?(rel) ->
            {acc, m}

          lvl >= 100 ->
            {Map.put(acc, name, 100), m}

          true ->
            {Map.put(acc, name, lvl), m}
        end
      end)

    done
  end

  @doc "技能是否可 enable parry/dodge/throwing/force（skill_expell_penalty 谓词）"
  def guards_special?(rel) do
    guards = Map.get(rel, :guards, [])
    Enum.any?(["parry", "dodge", "throwing", "force"], &(&1 in guards))
  end

  defp extras() do
    :persistent_term.get({__MODULE__, :extra}, %{})
  end
end

defmodule Kantele.Combat.Skills.DefaultActions do
  @moduledoc """
  未启用特技时的通用招式（拳脚与基础兵刃）
  """

  @unarmed [
    %{
      "action" => "$N右拳一收一送，直捣$n的$l",
      "force" => 0,
      "attack" => 10,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "挥拳猛击"
    },
    %{
      "action" => "$N侧身进步，一记肘锤撞向$n的$l",
      "force" => 0,
      "attack" => 15,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 8,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "肘锤"
    },
    %{
      "action" => "$N双掌翻飞，连环拍向$n的$l",
      "force" => 0,
      "attack" => 20,
      "dodge" => 5,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "震伤",
      "skill_name" => "连环双掌"
    }
  ]

  @weaponed [
    %{
      "action" => "$N手中兵刃一振，斜劈向$n的$l",
      "force" => 0,
      "attack" => 12,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 6,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "基础挥砍"
    },
    %{
      "action" => "$N手腕翻转，兵刃化作一道寒光罩向$n的$l",
      "force" => 0,
      "attack" => 18,
      "dodge" => 0,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "突刺"
    }
  ]

  def query_action(attack_skill, level, rng \\ &:rand.uniform/1)

  def query_action("unarmed", level, rng) do
    Kantele.Combat.Skill.pick_action(@unarmed, level, rng)
  end

  def query_action(_skill_type, level, rng) do
    Kantele.Combat.Skill.pick_action(@weaponed, level, rng)
  end
end
