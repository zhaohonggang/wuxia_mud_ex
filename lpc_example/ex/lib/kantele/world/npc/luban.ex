defmodule ExKantele.World.Npc.Luban do
  @moduledoc """
  鲁班（系统 NPC，对照 lpc_example/system_npc/system_npc_luban.c）

  结论：系统型 NPC（提供一项跨区服务），**半数据半行为**。
  - 数据：name/long/技能组（painting 雕刻、carpentry 木工）→ UCL characters
  - 行为：核心是“制作”（craft）系统 —— `make` 指定物件的材料需求表、
    按 jedao（打造/机关/镶嵌）检查手艺等级，成功后产出物品。
    这对应 Kalevala 应新增的 **Crafting 服务**（制作蓝图 + 需求校验 + 产出）。

  正确迁移姿势：UCL 摆一个 NPC + 新增 `Kantele.Crafting`（或 `ExKantele.Services.Crafting`），
  而不是把鲁班的所有互动逻辑塞进单个带行为的 NPC 文件。
  """

  # craft 蓝图（原文按 item 名 -> {技能, 所需等级, 所需材料/金钱}）
  @blueprints %{
    "桃木梳" => %{skill: "painting", rc: 1, ma: 0, jl: 0, mp: 150, price: 100},
    "铁钉"   => %{skill: "craft",   rc: 10, ma: 1, jl: 0, mp: 400, price: 500}
  }

  def craftable?(name, player_skills, level) do
    case Map.fetch(@blueprints, name) do
      {:ok, req} -> level >= req.rc and Map.get(player_skills, req.skill, 0) >= req.best_level()
      :error -> false
    end
  end

  @note "制作系统需底层新增：Kantele.Crafting（蓝图查找 + 等级校验 + 材料扣减 + 产出物进包）"
end
