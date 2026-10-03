defmodule Kantele.Feature.DamageTest do
  @moduledoc """
  `Kantele.Feature.Damage` 的 character/meta 桥接

  这个模块（LPC `feature/damage.c` 的移植）所有函数收发**character**，
  而 `Kantele.Character.PlayerMeta` 的接口是 **meta 进 / meta 出**。
  原来的代码把 `character` 直接传给 `PlayerMeta.update_damage/2` 等，
  一执行就抛 `no function clause matching`。

  为什么一直没暴露：`receive_damage/4` 只在 `who` 非 nil 时才走到
  `update_last_damage/2`，而现有三个调用方（berserk / hide / jingxiu）
  都传 `who = nil`，正好绕开。八卦阵「震」方向要昏厥，才第一次真正执行到。

  已知同型问题：`Kantele.Feature.Attack` 有同类调用（30+ 处），但那个模块
  目前无任何生产调用（死代码），本次未改，另行记录。
  """
  use ExUnit.Case, async: true

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Feature.Damage

  defp character do
    %Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: %Kantele.Character.Vitals{
          base_qi: 150,
          qi: 150,
          max_qi: 150,
          base_jing: 120,
          jing: 120,
          max_jing: 120,
          neili: 100,
          max_neili: 100
        },
        stats: %Kantele.Character.Stats{con: 20},
        combat: Kantele.Character.Combat.new(),
        temp: %{},
        damage: %{},
        env: %{},
        followers: []
      }
    }
  end

  test "receive_damage 扣精并返回 {:ok, character}" do
    assert {:ok, c} = Damage.receive_damage(character(), :jing, 50)
    assert c.meta.vitals.jing == 70
  end

  test "receive_damage 扣气" do
    assert {:ok, c} = Damage.receive_damage(character(), :qi, 50)
    assert c.meta.vitals.qi == 100
  end

  test "receive_damage 遇到负数返回 {:error, _} 而不是抛异常" do
    assert {:error, reason} = Damage.receive_damage(character(), :jing, -5)
    assert reason =~ "negative"
  end

  test "receive_wound 受创伤并返回 {:ok, character}" do
    assert {:ok, c} = Damage.receive_wound(character(), :qi, 50)
    assert is_map(c.meta)
  end

  test "unconcious 不再抛 no function clause matching（本次修的就是它）" do
    # 之前这里会炸：handle_unconcious -> put_damage_defeated_by ->
    # PlayerMeta.update_damage(character, ...) -> FunctionClauseError
    assert {:ok, c} = Damage.unconcious(character())
    assert is_map(c.meta)
    assert c.meta.vitals.qi == 0
    assert c.meta.vitals.jing == 0
  end

  test "damage 为 nil 也能跑（PlayerMeta 默认值是 nil，DB 恢复出来是 %{}）" do
    c = character()
    # 手动把 damage 置回 nil，模拟未初始化
    c = %{c | meta: %{c.meta | damage: nil}}

    assert {:ok, result} = Damage.unconcious(c)
    assert is_map(result.meta)
  end

  test "重复扣血不会累积出损坏的结构" do
    {:ok, c1} = Damage.receive_damage(character(), :jing, 30)
    {:ok, c2} = Damage.receive_damage(c1, :jing, 30)

    assert c2.meta.vitals.jing == 60
    assert is_map(c2.meta)
    assert is_map(c2.meta.damage)
  end
end