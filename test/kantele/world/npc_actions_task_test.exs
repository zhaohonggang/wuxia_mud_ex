defmodule Kantele.World.NpcActions.TaskTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
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

  describe "run/2（成功路径 @todo 占位）" do
    test "领工 + 完成 + 还了 → 播 NPC 台词，不发奖励、不改状态" do
      temp = %{"job_name" => "劈柴", "mark/劈完了" => 1, "mark/还了" => 1}
      conn2 = Task.run(conn(temp), params())

      assert out_text(conn2) =~ "干得不错，这是给你的奖赏。"
      # 无银两发放：背包不变（success 路径不 give_item）
      assert conn2.character.inventory == []
      # temp 未被清理（等奖励链路就绪后一并处理）
      assert conn2.character.meta.temp == temp
      # 无广播
      assert conn2.private.channel_changes == []
    end
  end
end
