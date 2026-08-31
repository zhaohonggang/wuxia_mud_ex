defmodule Kantele.ClassGenerateChinese do
  @moduledoc """
  随机中国武侠 NPC 生成基类（对应 ExKantele.World.ClassGenerateChinese / class_generate_chinese.ex）

  功能：
  - generate_name: 随机中文名
  - from_sect: 随机门派原型赋值
  - 基础属性赋值
  """

  alias Kantele.NameGenerator
  alias Kantele.Sects

  @doc "create() 主流程的 Elixir 化：起名 + 随机门派 + 基础属性"
  def build(gender, rng \\ &:rand.uniform/1) do
    name = NameGenerator.random_name(gender, rng)
    {sect_id, sect} = Sects.random(rng)

    %{
      name: name,
      sect: sect_id,
      class: sect.class,
      scale: sect.scale,
      attributes: %{str: 20, int: 20, con: 20, dex: 20, age: 20},
      combat_exp: 3_000_000,
      skills: sect.skills,
      maps: sect.maps,
      preps: sect.preps,
      carry: sect.carry
    }
  end

  @doc "按门派权重 scale 加权随机选原型（可替代等概随机）"
  def pick_weighted(rng \\ &:rand.uniform/1) do
    choices = Sects.all()
    total = Enum.reduce(choices, 0, fn {_k, v}, acc -> acc + (v.scale || 1) end)
    pick = rem(rng.(total * 100), total)

    Enum.find(choices, fn {_, v} -> (v.scale || 1) > pick end)
    |> elem(0)
  end
end
