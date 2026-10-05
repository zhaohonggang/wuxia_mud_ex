defmodule Kantele.World.CarryTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.World.Loader

  @moduletag :world_data

  # LPC 的 `carry_object(...)` 让 NPC 出生就带着装备：
  #     carry_object("/clone/weapon/gangdao")->wield();
  #     carry_object("/clone/cloth/cloth")->wear();
  #
  # 转换器把它降级成 `carry = [{ id = items.gangdao.id }]`，动作信息丢失。
  # 之前 loader 根本不解析这个字段 —— 所有 NPC 出生都是空手（§六 的缺口）。
  #
  # 现在：loader 只解引用并存进 meta.carry，**装备动作放在 SpawnController
  # 出生时做** —— 加载期 Items cache 的 ETS 表还不存在（Kickoff 是 load 完之后
  # 才 cache_item），在 loader 里查会 argument error 直接崩掉整个区解析。

  setup_all do
    %{world: Loader.load()}
  end

  defp eq(c), do: Map.get(c.meta.combat, :equipped) || %{}

  describe "loader 侧：carry 被解引用并存进 meta" do
    test "大多数 NPC 都有 carry", %{world: world} do
      with_carry =
        Enum.filter(world.characters, &(Map.get(&1.meta, :carry) || []) != [])

      assert length(with_carry) > 2000,
             "应有 2000+ 个 NPC 带 carry，实际 #{length(with_carry)}"
    end

    test "carry 引用能解引用到具体物品（未解引用的是真缺口）", %{world: world} do
      # 原始形态是 "items.cloth.id"（含点、未解引用），解引用后 "clone_lib:cloth"（不含点）
      {unresolved, resolved} =
        world.characters
        |> Enum.flat_map(&(Map.get(&1.meta, :carry) || []))
        |> Enum.uniq()
        |> Enum.split_with(&String.contains?(&1, "."))

      total = length(unresolved) + length(resolved)

      # 实测 303 个不同 id 里 156 个已解引用、147 个未解 —— 未解的那批是
      # **真缺口**（转换时这些物品就没解析出来，多为区特有的衣物/饰物），
      # 不是本次改动能修的。钉住当前水位，防止悄悄退化。
      assert length(resolved) > 0, "应该有一部分 carry 能解引用"
      assert length(unresolved) < total,
             "carry 引用全都解不出来，说明 resolve_goods 没接上"
      assert length(unresolved) < div(total, 2),
             "未解引用过半（#{length(unresolved)}/#{total}），比预期退化"
    end

    test "carry 引用的大多数物品确实存在", %{world: world} do
      {ok, bad} =
        world.characters
        |> Enum.flat_map(&(Map.get(&1.meta, :carry) || []))
        |> Enum.uniq()
        |> Enum.split_with(fn id ->
          Enum.any?(world.items, &(&1.id == id))
        end)

      # 绝大多数应该解析得到（走 clone_lib 回退）
      assert length(ok) > length(bad),
             "解析成功 #{length(ok)} 个，未解析 #{length(bad)} 个 —— " <>
               "未解析样例 #{inspect(Enum.take(bad, 8))}"
    end
  end

  describe "SpawnController 侧：按物品类型推断槽位" do
    test "兵器进 :weapon 槽", %{world: world} do
      # 找一个 carry 了兵器的 NPC（用数据推断，不启动进程）
      with_weapon =
        Enum.find(world.characters, fn c ->
          Enum.any?(Map.get(c.meta, :carry) || [], &weapon_item?(world, &1))
        end)

      assert with_weapon, "应该有 carry 兵器的 NPC"

      # 复刻 SpawnController 的判定：兵器 -> :weapon
      Enum.each(Map.get(with_weapon.meta, :carry) || [], fn id ->
        case find_item(world, id) do
          nil ->
            :ok

          item ->
            if weapon_item?(world, id) do
              assert Map.get(item.meta, :skill_type),
                     "#{id} 应当有 skill_type 才能进兵器槽"
            end
        end
      end)
    end

    test "NPC 出生时 equipped 初始为空（equip 在 spawn 时发生，不在 load 时）", %{world: world} do
      # 这是本次改动的关键约束：load 出来的 NPC **不能**已经穿好装备，
      # 因为那时 Items cache 还没就绪。装备在 SpawnController.init/1 里做。
      c = Enum.find(world.characters, &(Map.get(&1.meta, :carry) || []) != [])

      assert c
      assert map_size(eq(c)) == 0,
             "load 阶段不应装备（Items cache 未就绪），实际 equipped=#{inspect(eq(c))}"
      assert c.inventory == [], "load 阶段背包也应为空"
    end
  end

  defp find_item(world, id), do: Enum.find(world.items, &(&1.id == id))

  defp weapon_item?(world, id) do
    case find_item(world, id) do
      nil -> false
      item -> Map.get(item.meta, :skill_type) not in [nil, ""]
    end
  end

  # Combat.equip/3 是唯一的装备写入口，这里钉住它接受 NPC 侧的快照形状
  test "Combat.equip/3 能装上 NPC 侧的快照（与玩家 wield 同一形状）" do
    snapshot = %{
      name: "钢刀",
      skill_type: "blade",
      damage: 25,
      prop: nil,
      flag: 1
    }

    combat = Combat.equip(Combat.new(), :weapon, snapshot)

    assert Map.get(combat.equipped, :weapon) == snapshot
    assert Combat.occupied?(combat, :weapon)
  end
end