defmodule Kantele.World.InquiryHandlers.JobsJobTest do
  @moduledoc """
  P5-1e：打工类领活问询（kind = "jobs_job"），镜像 LPC
  `shutong.c` / `zhu.c` / `zeng.c` / `jiangong.c` 的 `ask_job()`。

  覆盖：asker 守门 / 房间不在注册表 / 已领活追问 / 按 `character.room_id`
  分流写对应 `job/*` temp + 回话文案。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.JobsJob

  # 与 Kantele.World.InquiryHandlers.JobsJob @room_jobs 保持一致
  @room_jobs %{
    "guiyun:shufang" => "job/copy",
    "city:shuyuan" => "job/copy",
    "city:garments" => "job/sew",
    "guanwai:shichang" => "job/move",
    "hangzhou:kuangshan" => "job/mine"
  }

  defp conn(room_id, opts \\ []) do
    meta = %PlayerMeta{
      marks: Keyword.get(opts, :marks, %{}),
      temp: Keyword.get(opts, :temp, %{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{})
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: room_id,
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp data(room_id, overrides \\ %{}) do
    Map.merge(
      %{
        kind: "jobs_job",
        config: %{},
        npc_name: "NPC",
        npc_room_id: room_id,
        asker_id: "player:test"
      },
      overrides
    )
  end

  # prompt 渲染条目的 data 不是 iodata（是 prompt 结构体），只取 Conn.Text。
  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp character(conn), do: conn.private.update_character || conn.character

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert Kantele.World.InquiryHandlers.lookup("jobs_job") == JobsJob
    end

    test "asker 不匹配 → 静默（无输出）" do
      conn2 = JobsJob.run(conn("guiyun:shufang"), %{}, data("guiyun:shufang", %{asker_id: "player:other"}))
      assert out_text(conn2) == ""
    end

    test "data 缺 asker_id → 不改 conn（不崩）" do
      conn2 = JobsJob.run(conn("guiyun:shufang"), %{}, %{kind: "jobs_job"})
      assert out_text(conn2) == ""
    end

    test "房间不在 @room_jobs → 「这里没有可领的工作。」" do
      conn2 = JobsJob.run(conn("wuguan:guofu_dayuan2"), %{}, data("wuguan:guofu_dayuan2"))
      assert out_text(conn2) =~ "这里没有可领的工作。"
    end

    test "已领活（job/* temp 非空）→ 「你不是已经领了工作吗？」" do
      conn2 = JobsJob.run(conn("guiyun:shufang", temp: %{"job/copy" => 1}), %{}, data("guiyun:shufang"))
      assert out_text(conn2) =~ "你不是已经领了工作吗？还不快去做。"
      # temp 不被覆盖（仍是原值）
      assert character(conn2).meta.temp["job/copy"] == 1
    end

    test "temp 为 0 → 按未领处理（LPC 0 为假）→ 派新活" do
      conn2 = JobsJob.run(conn("guiyun:shufang", temp: %{"job/copy" => 0}), %{}, data("guiyun:shufang"))

      refute out_text(conn2) =~ "你不是已经领了工作吗"
      assert character(conn2).meta.temp["job/copy"] == 1
    end
  end

  describe "按房间分流领活（assign_job）" do
    for {room_id, job_key} <- @room_jobs do
      test "#{room_id} → 写 #{job_key} temp + 回话文案" do
        conn2 = JobsJob.run(conn(unquote(room_id)), %{}, data(unquote(room_id)))
        temp = character(conn2).meta.temp
        text = out_text(conn2)

        assert Map.get(temp, unquote(job_key)) == 1
        # 只写了唯一一个 job/*（不污染其他房间键）
        assert Enum.count(temp, fn {k, v} -> String.starts_with?(k, "job/") and v == 1 end) == 1
        assert text != "" and is_binary(text)
      end
    end

    test "guiyun:shufang 文案：开始抄书" do
      conn2 = JobsJob.run(conn("guiyun:shufang"), %{}, data("guiyun:shufang"))
      assert out_text(conn2) =~ "你先到文房四宝前开始抄书"
    end

    test "guanwai:shichang 文案：搬运石料（job/move）" do
      conn2 = JobsJob.run(conn("guanwai:shichang"), %{}, data("guanwai:shichang"))
      assert character(conn2).meta.temp["job/move"] == 1
      assert out_text(conn2) =~ "去搬运石料"
    end

    test "hangzhou:kuangshan 文案：采矿（job/mine）" do
      conn2 = JobsJob.run(conn("hangzhou:kuangshan"), %{}, data("hangzhou:kuangshan"))
      assert character(conn2).meta.temp["job/mine"] == 1
      assert out_text(conn2) =~ "去采矿"
    end
  end

  describe "已领活追问（不重复派活）" do
    test "job/copy 已领 → 提示已领且 temp 不变" do
      conn2 = JobsJob.run(conn("city:shuyuan", temp: %{"job/copy" => 1}), %{}, data("city:shuyuan"))
      assert out_text(conn2) =~ "你不是已经领了工作吗？还不快去做。"
      assert character(conn2).meta.temp["job/copy"] == 1
    end

    test "job/sew 已领（非空串）→ 同样提示已领" do
      conn2 = JobsJob.run(conn("city:garments", temp: %{"job/sew" => "缝补"}), %{}, data("city:garments"))
      assert out_text(conn2) =~ "你不是已经领了工作吗？还不快去做。"
      assert character(conn2).meta.temp["job/sew"] == "缝补"
    end
  end
end
