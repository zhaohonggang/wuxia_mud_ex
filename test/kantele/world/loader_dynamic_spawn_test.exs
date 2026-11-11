defmodule Kantele.World.LoaderDynamicSpawnTest do
  use ExUnit.Case, async: true

  @moduledoc """
  灵蛇杖/蛇杖动态 spawn 的 UCL 校验（Task #119）。

  校验 data/world/baituo.ucl 中的 lingshezhang/shezhang 物品和 lingshe/snake 角色
  是否正确配置了 convert/bian 动作，确保动态 spawn 链路的数据端完整。
  """

  alias Kantele.World.Loader

  setup do
    %{world: Loader.load()}
  end

  test "lingshezhang UCL 配置 convert_lingshe 处理器", %{world: world} do
    item = Enum.find(world.items, &(&1.id == "baituo:lingshezhang"))
    refute item == nil, "baituo:lingshezhang 物品定义缺失"

    actions = item.meta.actions || []
    assert Enum.any?(actions, &(&1.verb == "convert" and &1.handler == "convert_lingshe")),
      "lingshezhang 缺少 convert_lingshe 动作：#{inspect(actions)}"
  end

  test "shezhang UCL 配置 convert_snake 处理器", %{world: world} do
    item = Enum.find(world.items, &(&1.id == "baituo:shezhang"))
    refute item == nil, "baituo:shezhang 物品定义缺失"

    actions = item.meta.actions || []
    assert Enum.any?(actions, &(&1.verb == "convert" and &1.handler == "convert_snake")),
      "shezhang 缺少 convert_snake 动作：#{inspect(actions)}"
  end

  test "lingshe 角色 UCL 配置 bian 动作", %{world: world} do
    baituo_zone = Enum.find(world.zones, &(&1.id == "baituo"))
    refute baituo_zone == nil, "baituo 区域缺失"

    char = Map.get(baituo_zone.characters, :lingshe)
    refute char == nil, "baituo:lingshe 角色定义缺失（zone.characters）"

    add_actions = char.meta.init.add_actions || []
    assert "bian" in add_actions,
      "lingshe 角色 init.add_actions 缺少 bian：#{inspect(add_actions)}"
  end

  test "snake 角色 UCL 配置 bian 动作", %{world: world} do
    baituo_zone = Enum.find(world.zones, &(&1.id == "baituo"))
    refute baituo_zone == nil, "baituo 区域缺失"

    char = Map.get(baituo_zone.characters, :snake)
    refute char == nil, "baituo:snake 角色定义缺失（zone.characters）"

    add_actions = char.meta.init.add_actions || []
    assert "bian" in add_actions,
      "snake 角色 init.add_actions 缺少 bian：#{inspect(add_actions)}"
  end
end
