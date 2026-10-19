defmodule Kantele.World.NpcActions.TxbwTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Txbw

  @room_id "city:wuguan"
  # 5000 gold，Money 口径 gold = 10_000 coin（与 LPC 5000*100*100 一致）。
  @cost_coins 50_000_000

  defp npc, do: %Kalevala.Character{name: "使者"}

  defp conn(stats, bank_coins) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: %PlayerMeta{stats: stats, bank_coins: bank_coins}
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(trailing),
    do: %{verb: "txbw", trailing: trailing, room_id: @room_id, npc: npc()}

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  # 经验达标的 stats
  defp rich, do: %Stats{combat_exp: 900_000}
  defp rich_conn, do: conn(rich(), @cost_coins)

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Txbw.run(rich_conn(), params("shaolin-shenfa") |> Map.put(:room_id, nil))
    end

    test "room_id 为空字符串 → :not_handled" do
      assert :not_handled = Txbw.run(rich_conn(), params("shaolin-shenfa") |> Map.put(:room_id, ""))
    end

    test "其他房间（wuguan 郭府大院）→ :not_handled" do
      assert :not_handled =
               Txbw.run(rich_conn(), params("shaolin-shenfa") |> Map.put(:room_id, "wuguan:guofu_dayuan2"))
    end
  end

  describe "run/2（用法提示）" do
    test "无 arg → 提示格式" do
      conn2 = Txbw.run(rich_conn(), params(""))

      assert out_text(conn2) =~ "格式：txbw <技能名称>, 举例：txbw shaolin-shenfa"
    end

    test "纯空白 arg → 同样提示（LPC sscanf 取不到词）" do
      conn2 = Txbw.run(rich_conn(), params("   "))

      assert out_text(conn2) =~ "格式：txbw"
    end
  end

  describe "run/2（经验守卫）" do
    test "exp 100（低于 800000）→ 实战经验不足" do
      conn2 = Txbw.run(conn(%Stats{combat_exp: 100}, @cost_coins), params("shaolin-shenfa"))

      assert out_text(conn2) =~ "你的实战经验不足，还是要多努力练功。"
    end

    test "exp 799999（差 1）→ 仍经验不足" do
      conn2 = Txbw.run(conn(%Stats{combat_exp: 799_999}, @cost_coins), params("shaolin-shenfa"))

      assert out_text(conn2) =~ "实战经验不足"
    end

    test "默认 stats（combat_exp 为 nil 按 0）→ 撞经验守卫（不崩溃）" do
      conn2 = Txbw.run(conn(%Stats{}, @cost_coins), params("shaolin-shenfa"))

      assert out_text(conn2) =~ "实战经验不足"
    end

    test "低经验 + 清单外技能 → 先撞经验守卫（LPC 判定顺序）" do
      conn2 = Txbw.run(conn(%Stats{combat_exp: 10}, @cost_coins), params("not-a-skill"))

      assert out_text(conn2) =~ "实战经验不足"
    end
  end

  describe "run/2（存款守卫）" do
    test "exp 够但存款为 0（未开户）→ 存款不足" do
      conn2 = Txbw.run(conn(rich(), 0), params("shaolin-shenfa"))

      assert out_text(conn2) =~ "你的存款不足。"
    end

    test "存款差 1 coin（49,999,999）→ 存款不足" do
      conn2 = Txbw.run(conn(rich(), @cost_coins - 1), params("shaolin-shenfa"))

      assert out_text(conn2) =~ "你的存款不足。"
    end

    test "存款恰够（50,000,000）→ 过存款守卫（落到清单守卫）" do
      conn2 = Txbw.run(conn(rich(), @cost_coins), params("not-a-skill"))

      assert out_text(conn2) =~ "看清楚了，这里没有你要学的技能！"
    end
  end

  describe "run/2（清单守卫）" do
    test "exp/存款都够 + 不在 29 个入门清单 → 看清楚了" do
      conn2 = Txbw.run(rich_conn(), params("tiannan-step"))

      assert out_text(conn2) =~ "看清楚了，这里没有你要学的技能！"
    end
  end

  describe "run/2（已掌握守卫）" do
    test "清单内技能且 stats.skills 已有等级 → 不要浪费金钱" do
      stats = %Stats{combat_exp: 900_000, skills: %{"shaolin-shenfa" => 100}}
      conn2 = Txbw.run(conn(stats, @cost_coins), params("shaolin-shenfa"))

      assert out_text(conn2) =~ "这个技能你已经掌握，不要再浪费金钱了！"
    end

    test "skills 为 nil 时按 0 计 → 走成功静默分支" do
      stats = %Stats{combat_exp: 900_000}
      conn2 = Txbw.run(conn(stats, @cost_coins), params("shaolin-shenfa"))

      assert out_text(conn2) == ""
    end
  end

  describe "run/2（成功路径 @todo 静默）" do
    test "清单内未学技能 + exp/存款达标 → 静默消费：无输出、无广播、无状态变更" do
      conn2 = Txbw.run(rich_conn(), params("hexing-bifa"))

      # 命令被消费（非 :not_handled），但 LPC 成功分支本就无输出
      assert conn2 != :not_handled
      assert out_text(conn2) == ""
      assert conn2.private.channel_changes == []
      # 未扣存款、未写技能（@todo 待 P9 学习系统接上）
      assert conn2.character.meta.bank_coins == @cost_coins
      assert conn2.character.meta.stats == rich()
    end
  end
end
