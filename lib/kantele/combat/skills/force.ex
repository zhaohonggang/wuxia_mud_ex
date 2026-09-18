defmodule Kantele.Combat.Skills.Force do
  @moduledoc """
  基本内功（对照 `kungfu/skill/force.c` 的运功载体）

  非法斗技能：无招式表、不可 practice；承载各内功共用的运功列表
  （exert 命令在 force 映射的内功模块里找不到时应退而查此处的公共运功，
  对应 LPC `kungfu/skill/force/power.c` 之类由所有内功共享的运功文件）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "power" => Kantele.Combat.Skills.Performs.Force.Power,
      "heal" => Kantele.Combat.Skills.Force.Heal,
      "inspire" => Kantele.Combat.Skills.Force.Inspire,
      "recover" => Kantele.Combat.Skills.Force.Recover,
      "lifeheal" => Kantele.Combat.Skills.Force.Lifeheal,
      "regenerate" => Kantele.Combat.Skills.Force.Regenerate,
      "dispel" => Kantele.Combat.Skills.Force.Dispel,
      "roar" => Kantele.Combat.Skills.Force.Roar,
      "shot" => Kantele.Combat.Skills.Force.Shot,
      "tianmo" => Kantele.Combat.Skills.Force.Tianmo,
      "xun" => Kantele.Combat.Skills.Force.Xun
    }
  end
end
