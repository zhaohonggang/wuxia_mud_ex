defmodule Kantele.World.NpcActions.JobsTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Jobs

  defp character(conn), do: conn.private.update_character || conn.character

  defp conn(room_id, temp \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: room_id,
        meta: %PlayerMeta{temp: temp}
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, trailing \\ ""),
    do: %{verb: "job", trailing: trailing, room_id: room_id, npc: %Kalevala.Character{name: "NPC"}}

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Jobs.run(conn(nil), params(nil))
    end

    test "room_id 为空字符串 → :not_handled" do
      assert :not_handled = Jobs.run(conn(""), params(""))
    end

    test "未注册房间（含已注册其他 verb 的房间）→ :not_handled" do
      assert :not_handled = Jobs.run(conn("wuguan:guofu_dayuan2"), params("wuguan:guofu_dayuan2"))
    end
  end

  describe "run/2（copy：未领活拒绝，房间可见）" do
    test "guiyun:shufang 书童：广播「千万别动文房四宝」" do
      conn2 = Jobs.run(conn("guiyun:shufang"), params("guiyun:shufang"))

      assert conn2 != :not_handled
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "书童喊道：拜托拜托，千万别动文房四宝"))
      # 广播类拒绝不推玩家私聊
      assert out_text(conn2) == ""
    end

    test "city:shuyuan 朱熹：文案不同（大喝道：给我放下）" do
      conn2 = Jobs.run(conn("city:shuyuan"), params("city:shuyuan"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "朱熹大喝道：给我放下，别乱动文房四宝"))
    end

    test "arg 被忽略（LPC do_copy 不判 arg）：无 arg 也走拒绝" do
      conn2 = Jobs.run(conn("guiyun:shufang"), params("guiyun:shufang", "whatever"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "文房四宝"))
    end
  end

  describe "run/2（sew：未领活拒绝）" do
    test "city:garments 曾柔：广播「有什么好玩的？」" do
      conn2 = Jobs.run(conn("city:garments"), params("city:garments"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "曾柔一声娇吒道：你给我放下，有什么好玩的？"))
    end
  end

  describe "run/2（mine/move：未领活拒绝，仅本人可见）" do
    test "guanwai:shichang mine：渲染「你又没领活」且不广播" do
      conn2 = Jobs.run(conn("guanwai:shichang"), params("guanwai:shichang"))

      assert String.contains?(out_text(conn2), "你又没领活，瞎忙活啥？")
      assert vision_texts(conn2) == []
    end

    test "guanwai:shichang move：同一 handler（LPC do_mine 兼管）" do
      conn2 = Jobs.run(conn("guanwai:shichang"), params("guanwai:shichang"))

      assert String.contains?(out_text(conn2), "你又没领活")
    end

    test "hangzhou:kuangshan mine：同一文案" do
      conn2 = Jobs.run(conn("hangzhou:kuangshan"), params("hangzhou:kuangshan"))

      assert String.contains?(out_text(conn2), "你又没领活，瞎忙活啥？")
    end
  end

  describe "run/2（job temp 真值语义：已领活进入多轮干活）" do
    test "job/copy 已领 → step 推进并广播第 1 步 vision + 渲染继续干活" do
      conn2 = Jobs.run(conn("guiyun:shufang", %{"job/copy" => 1}), params("guiyun:shufang"))

      assert conn2 != :not_handled
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "抄写第 1 页书"))
      assert String.contains?(out_text(conn2), "继续干活，已经干了 1 趟了")
    end

    test "job/copy 为 0 → 按未领拒（LPC 0 为假）" do
      conn2 = Jobs.run(conn("guiyun:shufang", %{"job/copy" => 0}), params("guiyun:shufang"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "文房四宝"))
    end

    test "job/mine 已领（非空串）→ step 推进并渲染第 1 步（玩家可见，非广播）" do
      conn2 = Jobs.run(conn("hangzhou:kuangshan", %{"job/mine" => "采矿"}), params("hangzhou:kuangshan"))

      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "第 1 趟采矿中")
      assert String.contains?(out_text(conn2), "继续干活，已经干了 1 趟了")
      assert vision_texts(conn2) == []
    end
  end

  describe "run/2（多轮完成：step 达总步数 → 结算奖励）" do
    test "copy 7 步完成：书童结尾文案 + 经验/潜能/钱 + temp 清 + mark 计数" do
      conn2 = Jobs.run(
        conn("guiyun:shufang", %{"job/copy" => 1, "job/copy/step" => 6}),
        params("guiyun:shufang")
      )

      assert conn2 != :not_handled
      # 完成文案
      assert String.contains?(out_text(conn2), "这几页抄得不错，这是给你的工钱。")
      # 经验/潜能文案
      assert String.contains?(out_text(conn2), "点经验和")
      assert String.contains?(out_text(conn2), "点潜能。")
      # 金钱文案
      assert String.contains?(out_text(conn2), "拿到")
      # 最后一步 vision
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "抄写第 7 页书"))
      # temp 已清（job/copy 和 job/copy/step 都不再在 temp 里）
      assert Map.keys(character(conn2).meta.temp) == []
      # mark 记录计数
      assert character(conn2).meta.marks == %{"mark/job_copy" => 1}
    end

    test "sew 5 步完成：曾柔结尾文案 + 奖励 + temp 清 + mark 计数" do
      conn2 = Jobs.run(
        conn("city:garments", %{"job/sew" => 1, "job/sew/step" => 4}),
        params("city:garments")
      )

      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "手艺不错，这是你的工钱。")
      assert String.contains?(out_text(conn2), "点经验和")
      assert String.contains?(out_text(conn2), "拿到")
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "缝补第 5 件衣料"))
      assert Map.keys(character(conn2).meta.temp) == []
      assert character(conn2).meta.marks == %{"mark/job_sew" => 1}
    end

    test "mine 10 步完成：监工结尾文案 + 奖励 + temp 清 + mark 计数（渲染模式，不广播）" do
      conn2 = Jobs.run(
        conn("hangzhou:kuangshan", %{"job/mine" => 1, "job/mine/step" => 9}),
        params("hangzhou:kuangshan")
      )

      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "凑合吧，这是你的工钱。")
      assert String.contains?(out_text(conn2), "点经验和")
      assert String.contains?(out_text(conn2), "拿到")
      # 渲染模式：vision 只给本人，channel_changes 无广播
      assert vision_texts(conn2) == []
      assert Map.keys(character(conn2).meta.temp) == []
      assert character(conn2).meta.marks == %{"mark/job_mine" => 1}
    end
  end
end
