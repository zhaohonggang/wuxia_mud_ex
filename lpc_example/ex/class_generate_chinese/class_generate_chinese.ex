defmodule ExKantele.World.ClassGenerateChinese do
  @moduledoc """
  对应原文件: lpc_example/class_npc/class_generate_chinese.c (1949 行)
             别名 chan_cler —— 「随机中国武侠 NPC」生成基类。

  迁移判定: 原评为 A，**实际是 C/多文件** —— 该样本不是“纯姓名生成器”，
  而是：
    ① create() 委托 NPC_D->generate_cn_name() 生成随机中文名（数据在
       `include/npc/chinese.c` 的 name daemon）
    ② 随机挑一个门派原型（38 个 from_*，每个 ~50 行：scale/class/技能树/
       map_skill/prepare_skill/chat_msg_combat/carry 装备）
    ③ 之后建随机 NPC 的基础属性与该门派武学

  因此本目录 = 多文件迁移（Kalevala 侧对应一个“随机 NPC 生成服务”）：
    - name_generator.ex        <- include/npc/chinese.c 姓名数据+算法
    - sects.ex                 <- 38 个门派原型数据（本 .c 的 from_* 的抽取）
    - class_generate_chinese.ex <- 本文件：组装基类

  本基类的职责(faithful)：
    generate_name -> random_name(gender)
    from_sect(随机) -> 赋 skills/maps/preps/class/carry 给该 NPC
    基础属性: str/int/con/dex=20, age=20, combat_exp=3000000 等
  """

  alias ExKantele.World.NameGenerator
  alias ExKantele.World.Sects

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
    {k, _} = Enum.find(choices, fn {_, v} -> (v.scale || 1) > pick end)
    k
  end
end
