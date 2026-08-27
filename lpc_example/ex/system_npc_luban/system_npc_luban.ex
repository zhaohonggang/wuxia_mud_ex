defmodule ExKantele.World.Npc.Luban do
  @moduledoc """
  对应原文件: lpc_example/system_npc/system_npc_luban.c (鲁班, 99972B)

  迁移判定: C —— **系统型服务 NPC**，半数据半行为。
    - 数据: name/long/技能组(painting 雕刻/carpentry 木工) -> UCL characters
    - 行为: 核心是“制作(Crafting)”系统——按物件查材料需求表、按
      jedao(打造/机关/镶嵌)检查手艺等级、扣料产出。对应 Kalevala 应
      新增的 Kantele.Crafting 服务层，而不是把互动逻辑塞进单个 NPC。
  """

  @blueprints %{
    "桃木梳" => %{skill: "painting", rc: 1, price: 100},
    "铁钉"   => %{skill: "craft", rc: 10, price: 500}
  }

  def craftable?(name, level) do
    case Map.fetch(@blueprints, name) do
      {:ok, req} -> level >= req.rc
      :error -> false
    end
  end

  @note "制作系统需底层新增 Kantele.Crafting(蓝图+等级校验+材料扣减+产出进包)"
end
