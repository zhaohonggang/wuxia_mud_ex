defmodule Kantele.Combat.PoisonHit do
  @moduledoc """
  中毒系 `hit_ob` 公共骨架

  LPC `kungfu/skill/` 下这一族文件的中毒段完全同构（只差技能 id / 门槛数值 /
  两个除数 / 文案 / condition 名）：

  ```c
  lvl  = me->query_skill("<skill>", 1);
  flvl = me->query("jiali");
  if (lvl < L || flvl < J || ! damage_bonus)
          return;

  if (flvl * 2 + random(lvl) > victim->query_skill("force") &&
      victim->affect_by(CND,
              ([ "level"    : flvl + random(flvl),
                 "id"       : me->query("id"),
                 "duration" : lvl / D1 + random(lvl / D2) ])))
  {
          return MSG;
  }
  ```

  对应本引擎 `Kantele.Combat.Skill.hit_ob/5` 的返回
  `{追加创伤, 文案, [{CND, para}]}`：这一族都**不追加创伤**（首项恒 0），
  只上 condition + 出文案。

  ## 参数（keyword）

  | 键 | 说明 | 默认 |
  |---|---|---|
  | `:skill`  | 技能 id（`query_skill("<skill>", 1)`） | 必填 |
  | `:cnd`    | condition 名（`affect_by` 第一参） | 必填 |
  | `:msg`    | 命中文案（保留 `$N/$n` 占位） | 必填 |
  | `:min_lvl`   | 技能等级门槛 `L` | 80 |
  | `:min_jiali` | 加力门槛 `J` | 10 |
  | `:div1`   | duration 第一除数 `D1` | 50 |
  | `:div2`   | duration 第二除数 `D2` | 20 |

  ## 与 LPC 的差异

  `affect_by` 的返回值在 LPC 里参与 `&&` 短路（daemon `do_effect` 返回 0 时
  文案不出）。POISON 系 daemon 的 `do_effect` 只在 `level/duration/id` 类型
  不对时返回 0，而这里构造的 para 三项都保证合法，所以短路恒为真——本实现
  按「恒真」处理，不再回传失败分支。
  """

  alias Kantele.Combat.Engine

  @doc "统一的 `hit_ob/5` 实现体（供各技能模块转调）"
  def strike(attacker, victim, damage, rng, opts) do
    skill = Keyword.fetch!(opts, :skill)
    cnd = Keyword.fetch!(opts, :cnd)
    msg = Keyword.fetch!(opts, :msg)

    min_lvl = Keyword.get(opts, :min_lvl, 80)
    min_jiali = Keyword.get(opts, :min_jiali, 10)
    div1 = Keyword.get(opts, :div1, 50)
    div2 = Keyword.get(opts, :div2, 20)

    lvl = Map.get(attacker.skills, skill, 0)
    flvl = attacker.jiali

    cond do
      lvl < min_lvl or flvl < min_jiali or damage == 0 ->
        {0, nil}

      flvl * 2 + Engine.rand(rng, lvl) > Map.get(victim.skills, "force", 0) ->
        {0, msg,
         [
           {cnd,
            %{
              "level" => flvl + Engine.rand(rng, flvl),
              "id" => attacker.id,
              "duration" => div(lvl, div1) + Engine.rand(rng, div(lvl, div2))
            }}
         ]}

      true ->
        {0, nil}
    end
  end
end
