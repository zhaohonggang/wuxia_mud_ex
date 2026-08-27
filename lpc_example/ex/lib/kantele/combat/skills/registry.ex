defmodule ExKantele.Combat.Skills do
  @moduledoc """
  迁移出的技能注册表（对照 lib/kantele/combat/skills.ex）

  仅作“若真正整合接入游戏”时的样例：把迁移出来的技能挂进
  主注册表（Kantele.Combat.Skills）即可，同时把行为里缺失的回调补齐。
  本文件不直接改游戏；只表达“接入路径”。
  """

  @skills_increment %{
    "taiji-quan" => ExKantele.Combat.Skills.TaijiQuan,
    "dugu-jiujian" => ExKantele.Combat.Skills.DuguJiujian
  }

  def added(), do: @skills_increment

  @note """
  接入步骤：
  1) 把这些 module 放进 lib/kantele/combat/skills/（而非 ex/）
  2) Kantele.Combat.Skills.@skills 增加两行
  3) 若用到 valid_combine / valid_damage / hit_ob / query_effect_parry /
     skill_improved，需先扩展 Kantele.Combat.Skill 行为与战斗引擎（见 migrate-notes）
  """
end
