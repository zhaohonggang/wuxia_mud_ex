defmodule Kantele.World.RoomActions.Wuguan.WorkTest do
  @moduledoc """
  P5 打工闭环中段：郭府五工作房干活动词（kind 统一走 `Wuguan.Work`，按 room_id 查配置）。

  覆盖：四道守门（已完工 / 活计不对 / 没领工具 / 参数词不对）、体力不足滑倒昏厥、
  正常推进进度、完工（wuguan_job 过期 + 进度达标 + 管事在场 → 写 mark/X完了）、
  wuguan_job 仍在进行时即便进度达标也不完工、管事不在场不完工、未知房间 :not_handled。
  """
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.YelvqiJob
  alias Kantele.World.RoomActions.Wuguan.Work

  # 各房配置（与 Work.@rooms 同步）：room_id / job / arg / progress / done / guanjia /
  # done_msg / no_job_msg / no_tool_msg / no_arg_msg
  @rooms [
    {"wuguan:guofu_mafang", "打扫马房", "mafang", "mark/扫", "mark/扫完了", "guanjia3",
     "马房管事嚷嚷道：喂喂喂，让你去覆命，还留在这里干嘛？\n",
     "马房管事对你喝道：没事你瞎折腾什么？\n",
     "马房管事讥笑道：你是想用什么来打扫呀，用手吗？\n", "你要打扫什么？\n"},
    {"wuguan:guofu_caidi1", "锄草", "cao", "mark/锄", "mark/锄完了", "guanjia5",
     "菜园管事嚷嚷道：喂喂喂，让你去覆命，还留在这里干嘛？\n",
     "菜园管事对你喝道：没事你瞎折腾什么？\n",
     "菜园管事讥笑道：你是想用什么来锄草呀，用手吗？\n", "你要锄什么？\n"},
    {"wuguan:guofu_caidi2", "浇菜地", "shui", "mark/浇", "mark/浇完了", "guanjia6",
     "菜园管事嚷嚷道：喂喂喂，让你去覆命，还留在这里干嘛？\n",
     "菜园管事对你喝道：没事你瞎折腾什么？\n",
     "菜园管事讥笑道：你想用什么来舀水浇呀，用手吗？\n", "你要浇什么？\n"},
    {"wuguan:guofu_chaifang", "劈柴", "chai", "mark/劈", "mark/劈完了", "guanjia1",
     "柴房管事嚷嚷道：喂喂喂，让你去覆命，还留在这里干嘛？\n",
     "柴房管事对你喝道：没事你瞎折腾什么？\n",
     "柴房管事讥笑道：你准备用什么来劈柴呀，用手吗？\n", "你要劈什么？\n"},
    {"wuguan:guofu_mufang", "锯木头", "mutou", "mark/锯", "mark/锯完了", "guanjia2",
     "木房管事嚷嚷道：喂喂喂，让你去覆命，还留在这里干嘛？\n",
     "木房管事对你喝道：没事你瞎折腾什么？\n",
     "木房管事讥笑道：你想用什么来锯木头，用手掰吗？\n", "你要锯什么？\n"}
  ]

  defp character(opts) do
    meta = %PlayerMeta{
      temp: Keyword.get(opts, :temp, %{}),
      vitals:
        Keyword.get(opts, :vitals, %Vitals{
          jing: 120,
          max_jing: 120,
          qi: 150,
          max_qi: 150
        }),
      stats: %Stats{
        con: Keyword.get(opts, :con, 30),
        str: Keyword.get(opts, :str, 30)
      },
      combat: Combat.new(),
      damage: %{},
      env: %{}
    }

    %Kalevala.Character{
      id: "player:test",
      name: "玩家",
      room_id: Keyword.get(opts, :room_id, "wuguan:guofu_mafang"),
      inventory: [],
      meta: meta
    }
  end

  defp conn(opts) do
    chars = Keyword.get(opts, :chars, [])

    %Conn{
      character: character(opts),
      private: %Conn.Private{
        channel_changes: [],
        room: %{characters: chars}
      },
      session: Keyword.get(opts, :session, %{}),
      output: []
    }
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp char(conn), do: conn.private.update_character || conn.character

  defp temp_get(conn, key) do
    Map.get(char(conn).meta.temp || %{}, key)
  end

  defp guanjia(short_id), do: %{id: "wuguan:#{short_id}", name: "管事", aliases: ["guanshi"]}

  defp working_temp(job, progress_key, progress_val) do
    %{"job_name" => job, "mark/工具" => 1, progress_key => progress_val}
  end

  describe "守门分支" do
    test "未知房间 → :not_handled" do
      assert Work.run(conn(room_id: "wuguan:guofu_dayuan2"), %{
               room_id: "wuguan:guofu_dayuan2",
               trailing: "mafang"
             }) == :not_handled
    end

    test "已完工 → 督促覆命（五房）" do
      for {room_id, job, arg, _p, done, _g, done_msg, _nj, _nt, _na} <- @rooms do
        c = conn(room_id: room_id, temp: Map.put(working_temp(job, "tmp", 0), done, 1))
        res = Work.run(c, %{room_id: room_id, trailing: arg})
        assert out_text(res) == done_msg
        assert temp_get(res, done) == 1
      end
    end

    test "活计不对 → 喝道瞎折腾（五房）" do
      for {room_id, _job, arg, _p, _d, _g, _dm, no_job_msg, _nt, _na} <- @rooms do
        c = conn(room_id: room_id, temp: %{"job_name" => "别的活计", "mark/工具" => 1})
        res = Work.run(c, %{room_id: room_id, trailing: arg})
        assert out_text(res) == no_job_msg
      end
    end

    test "没领工具 → 用手吗（五房）" do
      for {room_id, job, arg, _p, _d, _g, _dm, _nj, no_tool_msg, _na} <- @rooms do
        c = conn(room_id: room_id, temp: %{"job_name" => job})
        res = Work.run(c, %{room_id: room_id, trailing: arg})
        assert out_text(res) == no_tool_msg
      end
    end

    test "参数词不对 → 你要X什么（五房）" do
      for {room_id, job, arg, _p, _d, _g, _dm, _nj, _nt, no_arg_msg} <- @rooms do
        c = conn(room_id: room_id, temp: %{"job_name" => job, "mark/工具" => 1})
        res = Work.run(c, %{room_id: room_id, trailing: "乱七八糟"})
        assert out_text(res) == no_arg_msg
        # 文案与正确参数无关（此处仅校验拒绝文案）
        _ = arg
      end
    end
  end

  describe "干活：体力 / 进度 / 完工" do
    test "体力不足 → 滑倒昏厥，不推进进度、不完工" do
      c =
        conn(
          room_id: "wuguan:guofu_mafang",
          temp: working_temp("打扫马房", "mark/扫", 5),
          vitals: %Vitals{jing: 0, max_jing: 120, qi: 0, max_qi: 150},
          chars: [guanjia("guanjia3")]
        )

      res = Work.run(c, %{room_id: "wuguan:guofu_mafang", trailing: "mafang"})
      # 不推进进度、不写完工
      assert temp_get(res, "mark/扫") == 5
      assert temp_get(res, "mark/扫完了") == nil
      # 昏厥：气血/精力归零
      vit = char(res).meta.vitals
      assert vit.qi == 0
      assert vit.jing == 0
    end

    test "正常推进：wuguan_job 过期 + 进度低 → 仅 +1，不完工" do
      c =
        conn(
          room_id: "wuguan:guofu_mafang",
          temp: working_temp("打扫马房", "mark/扫", 1),
          chars: [guanjia("guanjia3")]
        )

      res = Work.run(c, %{room_id: "wuguan:guofu_mafang", trailing: "mafang"})
      # 进度从 1 推进到 2（1 远低于阈值 10+random(10)），不标记完工
      assert temp_get(res, "mark/扫") == 2
      assert temp_get(res, "mark/扫完了") == nil
    end

    test "完工：wuguan_job 过期 + 进度高 + 管事在场 → 写 mark/扫完了" do
      c =
        conn(
          room_id: "wuguan:guofu_mafang",
          temp: working_temp("打扫马房", "mark/扫", 100),
          chars: [guanjia("guanjia3")]
        )

      res = Work.run(c, %{room_id: "wuguan:guofu_mafang", trailing: "mafang"})
      assert temp_get(res, "mark/扫完了") != nil
      # 完工分支不再累加进度
      assert temp_get(res, "mark/扫") == 100
    end

    test "wuguan_job 仍在进行 → 即便进度高也不完工" do
      c =
        conn(
          room_id: "wuguan:guofu_mafang",
          temp: working_temp("打扫马房", "mark/扫", 100),
          chars: [guanjia("guanjia3")],
          session: %{"conditions" => %{"wuguan_job" => %{"duration" => 3}}}
        )

      res = Work.run(c, %{room_id: "wuguan:guofu_mafang", trailing: "mafang"})
      assert temp_get(res, "mark/扫完了") == nil
      # 仍在工期：继续推进进度
      assert temp_get(res, "mark/扫") == 101
    end

    test "管事不在场 → 不完工（按房验证）" do
      for {room_id, job, arg, prog, done, _guan, _dm, _nj, _nt, _na} <- @rooms do
        c =
          conn(
            room_id: room_id,
            temp: working_temp(job, prog, 100),
            chars: [%{id: "wuguan:someone_else", name: "路人", aliases: []}]
          )

        res = Work.run(c, %{room_id: room_id, trailing: arg})
        assert temp_get(res, done) == nil, "房间 #{room_id} 管事不在却完工了"
        assert temp_get(res, prog) == 101
      end
    end

    test "全部五房都能各自完工（管事在场、进度高、工期满）" do
      for {room_id, job, arg, prog, done, guan, _dm, _nj, _nt, _na} <- @rooms do
        c =
          conn(
            room_id: room_id,
            temp: working_temp(job, prog, 100),
            chars: [guanjia(guan)]
          )

        res = Work.run(c, %{room_id: room_id, trailing: arg})
        assert temp_get(res, done) != nil, "房间 #{room_id} 未能完工"
      end
    end
  end

  describe "与领工入口衔接" do
    test "YelvqiJob 派活写入 job_name，Work 据此校验" do
      conn0 =
        conn(
          room_id: "wuguan:guofu_mafang",
          temp: %{},
          session: %{}
        )

      conn1 = YelvqiJob.run(conn0, %{}, %{kind: "yelvqi_job", asker_id: "player:test"})
      job = temp_get(conn1, "job_name")
      assert job in ~w(打扫马房 锯木头 劈柴 浇菜地 锄草)
    end
  end
end
