defmodule Kantele.World.JobsE2ETest do
  @moduledoc """
  P5-1e 端到端集成测试：把「问询领活 → 多轮干活 → 结算奖励」整条链路打通。

  串联两个模块：
  - `Kantele.World.InquiryHandlers.JobsJob`（kind = "jobs_job"，写 `job/*` temp）
  - `Kantele.World.NpcActions.Jobs`（读 `job/*` temp，推 step、广播/渲染 vision、结算）

  覆盖：
  1. 问书童领活 → 7 步抄书 → 发经验/潜能/钱 + 清 temp + 记 mark + 可再次领活；
  2. 渲染模式（hangzhou:kuangshan 监工采矿 10 步，不广播）；
  3. 未领活直接干活 → 书童拒绝（广播文房四宝），不写 step temp。

  角色 id 用 `"integration:player"`（binary 但不以 `"player:"` 开头），
  这样 `Jobs.persist/1` 的 `Records.save/1` 守卫不会触发，避免沙盒刷 DB 日志，
  同时又能让 `JobsJob` 的 `asker_id == character.id` 守门生效。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.InquiryHandlers.JobsJob
  alias Kantele.World.NpcActions.Jobs

  @player_id "integration:player"

  defp e2e_conn(room_id, opts \\ []) do
    meta = %PlayerMeta{
      marks: Keyword.get(opts, :marks, %{}),
      temp: Keyword.get(opts, :temp, %{}),
      vitals: %Vitals{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: @player_id,
        name: "玩家",
        room_id: room_id,
        meta: meta
      },
      private: %Conn.Private{
        room: %Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp e2e_data(room_id) do
    %{
      kind: "jobs_job",
      config: %{},
      npc_name: "NPC",
      npc_room_id: room_id,
      asker_id: @player_id
    }
  end

  defp params(room_id, verb) do
    %{verb: verb, trailing: "", room_id: room_id, npc: %Kalevala.Character{name: "NPC"}}
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

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp character(conn), do: conn.private.update_character || conn.character

  # 连续执行 count 次 Jobs.run（每轮推进一步），返回最终 conn。
  defp run_steps(conn, room_id, verb, count) do
    Enum.reduce(1..count, conn, fn _, c -> Jobs.run(c, params(room_id, verb)) end)
  end

  describe "guiyun:shufang 书童：领活 → 7 步抄书 → 结算 → 可再领" do
    test "完整链路 + 中途追问不打断进度" do
      room_id = "guiyun:shufang"
      conn = e2e_conn(room_id)

      # 前置：未领活
      assert character(conn).meta.temp["job/copy"] == nil

      # 1) 问书童领活 → 写 job/copy = 1，回领活文案
      conn = JobsJob.run(conn, %{}, e2e_data(room_id))
      assert character(conn).meta.temp["job/copy"] == 1
      assert out_text(conn) =~ "你先到文房四宝前开始抄书"

      # 2) 第 1 步：step = 1，广播「抄写第 1 页书」，提示继续；temp 未清
      conn = Jobs.run(conn, params(room_id, "copy"))
      assert character(conn).meta.temp["job/copy/step"] == 1
      assert Enum.any?(vision_texts(conn), &String.contains?(&1, "抄写第 1 页书"))
      assert out_text(conn) =~ "继续干活，已经干了 1 趟了。"
      assert character(conn).meta.temp["job/copy"] == 1

      # 3) 干活途中再次追问 → 提示已领，不重置进度
      conn = JobsJob.run(conn, %{}, e2e_data(room_id))
      assert out_text(conn) =~ "你不是已经领了工作吗？还不快去做。"
      assert character(conn).meta.temp["job/copy/step"] == 1

      # 4) 第 2~7 步（再跑 6 轮，到达总步数 7 → 结算）
      conn = run_steps(conn, room_id, "copy", 6)

      # 5) 结算文案 + 奖励（经验/潜能/钱）
      assert out_text(conn) =~ "这几页抄得不错，这是给你的工钱。"
      assert out_text(conn) =~ "点经验和"
      assert out_text(conn) =~ "点潜能。"
      assert out_text(conn) =~ "拿到"
      # 最后一步 vision
      assert Enum.any?(vision_texts(conn), &String.contains?(&1, "抄写第 7 页书"))
      # temp 已清（job/copy 与 job/copy/step 都移除）
      assert character(conn).meta.temp == %{}
      # 持久 mark 计数
      assert character(conn).meta.marks == %{"mark/job_copy" => 1}

      # 6) 完成后可再次领活（temp 已清，JobsJob 重新派活）
      conn = JobsJob.run(conn, %{}, e2e_data(room_id))
      assert character(conn).meta.temp["job/copy"] == 1
    end
  end

  describe "hangzhou:kuangshan 监工（渲染模式）：领活 → 10 步采矿 → 结算" do
    test "渲染模式不广播，玩家本人可见 step 文案" do
      room_id = "hangzhou:kuangshan"
      conn = e2e_conn(room_id)

      # 问监工领活 → 写 job/mine = 1
      conn = JobsJob.run(conn, %{}, e2e_data(room_id))
      assert character(conn).meta.temp["job/mine"] == 1
      assert out_text(conn) =~ "去采矿吧。"

      # 10 步采矿（到达总步数 10 → 结算）
      conn = run_steps(conn, room_id, "mine", 10)

      # 结算文案 + 奖励
      assert out_text(conn) =~ "凑合吧，这是你的工钱。"
      assert out_text(conn) =~ "点经验和"
      assert out_text(conn) =~ "点潜能。"
      assert out_text(conn) =~ "拿到"
      # 渲染模式：step 文案到达玩家本人
      assert out_text(conn) =~ "第 1 趟采矿中"
      # 渲染模式：无广播 vision
      assert vision_texts(conn) == []
      # temp 清 + mark 记
      assert character(conn).meta.temp == %{}
      assert character(conn).meta.marks == %{"mark/job_mine" => 1}
    end
  end

  describe "未领活直接干活 → 守门拒绝" do
    test "guiyun:shufang 书童广播拒绝，不写 step temp" do
      room_id = "guiyun:shufang"
      conn = e2e_conn(room_id)

      conn2 = Jobs.run(conn, params(room_id, "copy"))

      assert conn2 != :not_handled
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "书童喊道：拜托拜托，千万别动文房四宝"))
      # 拒绝路径不写任何 temp
      assert character(conn2).meta.temp == %{}
      # 广播类拒绝不推玩家私聊
      assert out_text(conn2) == ""
    end
  end
end
