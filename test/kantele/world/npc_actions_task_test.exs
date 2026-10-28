defmodule Kantele.World.NpcActions.TaskTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Task

  @room_id "wuguan:guofu_dayuan2"

  defp npc, do: %Kalevala.Character{name: "耶律齐"}

  defp conn(temp \\ %{}, session \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: %PlayerMeta{temp: temp}
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      session: session,
      output: []
    }
  end

  defp params(trailing \\ "ok"),
    do: %{verb: "task", trailing: trailing, room_id: @room_id, npc: npc()}

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp character(conn), do: conn.private.update_character || conn.character

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Task.run(conn(), params() |> Map.put(:room_id, nil))
    end

    test "room_id 为空字符串 → :not_handled" do
      assert :not_handled = Task.run(conn(), params() |> Map.put(:room_id, ""))
    end

    test "其他房间（wuguan 饭厅，serve 同区）→ :not_handled" do
      assert :not_handled = Task.run(conn(), params() |> Map.put(:room_id, "wuguan:guofu_fanting"))
    end
  end

  describe "run/2（arg 非 ok 放行全局）" do
    test "无 arg → :not_handled（LPC return 0）" do
      assert :not_handled = Task.run(conn(), params(""))
    end

    test "arg 为别的词 → :not_handled" do
      assert :not_handled = Task.run(conn(), params("finish"))
    end

    test "arg 带首尾空白（\"  ok  \"）→ trim 后按 ok 处理" do
      conn2 = Task.run(conn(), params("  ok  "))

      assert conn2 != :not_handled
      assert out_text(conn2) =~ "我没给你工作"
    end
  end

  describe "run/2（守卫）" do
    test "未领工作（无 job_name）→ 拒绝「我没给你工作」" do
      conn2 = Task.run(conn(), params())

      assert out_text(conn2) =~ "我没给你工作，怎么跑来覆命了"
      assert conn2.private.channel_changes == []
    end

    test "job_name 为空串 → 同样按未领工作拒绝" do
      conn2 = Task.run(conn(%{"job_name" => ""}), params())

      assert out_text(conn2) =~ "我没给你工作"
    end

    test "已领工但没有任何完成 mark → 拒绝「干完了吗」" do
      conn2 = Task.run(conn(%{"job_name" => "劈柴"}), params())

      assert out_text(conn2) =~ "我让你干的事都干完了吗"
    end

    test "mark/劈完了 一个即算完成（落到下一守卫）" do
      conn2 = Task.run(conn(%{"job_name" => "劈柴", "mark/劈完了" => 1}), params())

      assert out_text(conn2) =~ "还是先把工具还了"
    end

    test "mark/挑完了（不在 LPC names 数组）同样算完成" do
      conn2 = Task.run(conn(%{"job_name" => "劈柴", "mark/挑完了" => 1}), params())

      assert out_text(conn2) =~ "还是先把工具还了"
    end

    test "完成 mark + 无 mark/还了 → 拒绝「先把工具还了」" do
      conn2 = Task.run(conn(%{"job_name" => "锯木头", "mark/锯完了" => 1}), params())

      assert out_text(conn2) =~ "还是先把工具还了再说吧"
    end

    test "完成 mark 为零值（0）→ 按未完成拦（LPC 0 为假）" do
      conn2 = Task.run(conn(%{"job_name" => "锯木头", "mark/锯完了" => 0}), params())

      assert out_text(conn2) =~ "我让你干的事都干完了吗"
    end

    test "session conditions 有 wuguan_job → 拒绝「怎么这么快」" do
      temp = %{"job_name" => "劈柴", "mark/劈完了" => 1}
      session = %{"conditions" => %{"wuguan_job" => %{"level" => 3}}}
      conn2 = Task.run(conn(temp, session), params())

      assert out_text(conn2) =~ "怎么这么快，是不是没做完啊"
    end

    test "session conditions 只有别的条件 → 太快分支不触发" do
      temp = %{"job_name" => "劈柴", "mark/劈完了" => 1}
      session = %{"conditions" => %{"poison" => %{"level" => 1}}}
      conn2 = Task.run(conn(temp, session), params())

      assert out_text(conn2) =~ "还是先把工具还了"
    end
  end

  describe "run/2（成功路径：奖励发放）" do
    test "领工 + 完成 + 还了 → 发银两 + 经验/潜能 + 清 temp + 记 mark/guofu_job + 播文案" do
      meta = %PlayerMeta{
        temp: %{"job_name" => "劈柴", "mark/劈完了" => 1, "mark/还了" => 1},
        stats: %Stats{combat_exp: 1000, potential: 100, learned_points: 0}
      }
      c = %Conn{
        character: %Kalevala.Character{name: "玩家", room_id: @room_id, meta: meta},
        private: %Conn.Private{room: %Kantele.World.Room{id: @room_id}, channel_changes: []},
        session: %{},
        output: []
      }
      conn2 = Task.run(c, params())

      # NPC 台词 + 奖励文案
      assert out_text(conn2) =~ "干得不错，这是给你的奖赏。"
      assert out_text(conn2) =~ "耶律齐给你"
      assert out_text(conn2) =~ "你获得了"
      assert out_text(conn2) =~ "点经验和"
      assert out_text(conn2) =~ "点潜能。"

      # 银两：1~5 两白银 = 100~500 铜钱
      coins = character(conn2).meta.coins
      assert coins >= 100
      assert coins <= 500
      assert rem(coins, 100) == 0

      # 经验：50~69
      assert character(conn2).meta.stats.combat_exp >= 1050   # 默认 1000 + 50~69
      assert character(conn2).meta.stats.combat_exp <= 1069

      # 潜能：默认 100，learned 0 → 上限 100，improve_potential 封顶不加，
      # 按 LPC 语义额外给 5 → 105
      assert character(conn2).meta.stats.potential == 105

      # temp 被清理：job_name、mark/劈完了、mark/还了 都删除了
      assert Map.get(character(conn2).meta.temp, "job_name") == nil
      assert Map.get(character(conn2).meta.temp, "mark/劈完了") == nil
      assert Map.get(character(conn2).meta.temp, "mark/还了") == nil

      # 持久 mark 记入
      assert character(conn2).meta.marks["mark/guofu_job"] == 1

      # 无广播（仅私发）
      assert conn2.private.channel_changes == []
    end

    test "潜能未满时正常发放（不走最小值 5）" do
      # 潜能 50，learned 0 → 上限 100，room = 50，正常发放 25~34
      meta = %PlayerMeta{
        temp: %{"job_name" => "锯木头", "mark/锯完了" => 1, "mark/还了" => 1},
        stats: %Stats{potential: 50, learned_points: 0, combat_exp: 1000}
      }
      c = %Conn{
        character: %Kalevala.Character{name: "玩家", room_id: @room_id, meta: meta},
        private: %Conn.Private{room: %Kantele.World.Room{id: @room_id}, channel_changes: []},
        session: %{},
        output: []
      }
      conn2 = Task.run(c, params())

      pot = character(conn2).meta.stats.potential
      assert pot >= 75   # 50 + 25~34
      assert pot <= 84
      assert character(conn2).meta.marks["mark/guofu_job"] == 1
      assert Map.get(character(conn2).meta.temp, "job_name") == nil
    end

    test "潜能已达上限 → improve_potential 封顶，仍给最小值 5" do
      # potential=200, learned=50 → 潜能上限=150，available=150，room=0，
      # improve_potential 不加，按 LPC 语义给 5 → 205
      meta = %PlayerMeta{
        temp: %{"job_name" => "浇菜地", "mark/浇完了" => 1, "mark/还了" => 1},
        stats: %Stats{potential: 200, learned_points: 50, combat_exp: 2000}
      }
      c = %Conn{
        character: %Kalevala.Character{name: "玩家", room_id: @room_id, meta: meta},
        private: %Conn.Private{room: %Kantele.World.Room{id: @room_id}, channel_changes: []},
        session: %{},
        output: []
      }
      conn2 = Task.run(c, params())

      # 潜能已达上限，不加 pot_gain，给最小值 5 → 205
      assert character(conn2).meta.stats.potential == 205
      assert character(conn2).meta.marks["mark/guofu_job"] == 1
    end

    test "非 player id 不落盘（不崩溃，id 为 nil 时跳过 Records.save）" do
      temp = %{"job_name" => "劈柴", "mark/劈完了" => 1, "mark/还了" => 1}
      conn2 = Task.run(conn(temp), params())
      # 仅验证不崩溃，内存态正确即可
      assert character(conn2).meta.marks["mark/guofu_job"] == 1
    end
  end
end
