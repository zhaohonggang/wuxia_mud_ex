defmodule Kantele.Meta.TrimContractTest do
  @moduledoc """
  `Kalevala.Meta.Trim` 的保留字段契约

  背景：角色进入房间时，Movement 事件里的 character、房间 state 里的 characters
  都经过 `Conn.private/1`（内部就是 `Meta.trim`）。**房间侧逻辑读到的 meta 是裁剪过的**，
  所以裁剪清单少一个字段，就等于让某个功能静默失效：

    - 少了 `:guarder` -> `Room.check_guarders` 恒拿到 nil，守卫/盘查从未拦截
    - 少了 `:temp`    -> 护主 guarded 逻辑读不到数据；更糟的是 valid_leave 条件
                        `!me->query_temp('rent_paid')` 恒为真，玩家永远上不了客栈二楼
    - 少了 `:env`     -> `me->query("gender")` 之类恒为 nil
    - 少了 `:stats`   -> `me->query_skill("force") < 500` 恒成立
    - 少了 `:aliases` -> `present('shi wei', ...)` 永远匹配不到人

  本模块把这些「不能裁」写成测试，避免以后有人为了省内存把它裁回去。
  """
  use ExUnit.Case, async: true

  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta

  @player_keep [:vitals, :stats, :family, :temp, :env]
  @npc_keep [:vitals, :stats, :guarder, :aliases]

  test "PlayerMeta 裁剪后仍带房间侧要读的字段" do
    meta = %PlayerMeta{
      vitals: %{hp: 1},
      stats: %{skills: %{"force" => %{level: 300}}},
      family: %{family_name: "武当派"},
      temp: %{"rent_paid" => true},
      env: %{"gender" => "男"},
      coins: 999
    }

    trimmed = Kalevala.Meta.trim(meta)

    Enum.each(@player_keep, fn key ->
      assert Map.has_key?(trimmed, key), "PlayerMeta 裁剪后丢了 #{key}"
    end)

    # 不在清单里的字段仍然会被裁掉（trim 的本意就是省内存）
    refute Map.has_key?(trimmed, :coins)
  end

  test "NonPlayerMeta 裁剪后仍带 guarder" do
    meta = %NonPlayerMeta{
      vitals: %{hp: 1},
      stats: %{skills: %{}},
      guarder: %{family: "白驼山庄"},
      aliases: ["shi wei"],
      goods: ["sword"],
      inquiries: %{}
    }

    trimmed = Kalevala.Meta.trim(meta)

    Enum.each(@npc_keep, fn key ->
      assert Map.has_key?(trimmed, key), "NonPlayerMeta 裁剪后丢了 #{key}"
    end)

    assert trimmed.guarder.family == "白驼山庄"
    refute Map.has_key?(trimmed, :inquiries)
  end

  test "守卫判定能从裁剪后的 meta 读到 guarder 配置（否则守卫从不拦截）" do
    meta = %NonPlayerMeta{
      vitals: %{},
      guarder: %{family: "白驼山庄"},
      aliases: []
    }

    trimmed = Kalevala.Meta.trim(meta)

    assert Kantele.Npc.Guarder.is_guarder?(struct(Kalevala.Character, %{
             name: "守卫",
             pid: self(),
             meta: trimmed
           }))
  end

  @tag :world_data
  test "valid_leave 条件在裁剪后的玩家 meta 上求值正确（客栈交房费才能上楼）" do
    world = Kantele.World.Loader.load()

    # changan:kezhan 的 valid_leave：没交房费不许上楼（对应 LPC changan/kezhan.c）
    room = Enum.find(world.rooms, &(&1.id == "changan:kezhan"))
    assert room, "changan:kezhan 应存在"

    veto =
      Enum.find(room.exit_vetoes, fn v ->
        is_binary(Map.get(v, :condition)) and String.contains?(v.condition, "rent_paid")
      end)

    assert veto, "应有「未交房费不许上楼」的阻挡条件"

    # 已交房费：放行
    paid = trimmed_player(%{"rent_paid" => true})
    assert Kantele.World.LpcCondition.check(veto, ctx(room, paid)) == :allow

    # 未交房费：拦下（如果 temp 被裁掉，这里会错误地放行）
    unpaid = trimmed_player(%{})
    assert {:block, _} = Kantele.World.LpcCondition.check(veto, ctx(room, unpaid))
  end

  defp trimmed_player(temp) do
    meta = %PlayerMeta{vitals: %{}, stats: %{}, temp: temp, env: %{}}

    %{
      pid: self(),
      name: "测试玩家",
      meta: Kalevala.Meta.trim(meta)
    }
  end

  defp ctx(room, player) do
    Kantele.World.ExitVetoContext.build(
      dir: "up",
      me: player,
      room: room,
      context: %{characters: []}
    )
  end
end