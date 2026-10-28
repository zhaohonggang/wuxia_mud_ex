defmodule Kantele.World.InquiryHandlers.YelvqiJobTest do
  @moduledoc """
  P5-1d：耶律齐领活计问询（kind = "yelvqi_job"），镜像 LPC
  `/d/wuguan/npc/yelvqi.c` `ask_job()`。

  覆盖：asker 守门 / 已领活 / 经验过高 / 已外出 / random 派活写 job_name temp +
  wuguan_job 计时 condition；另含 `Kantele.WuguanJob` condition daemon 单元。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.WuguanJob
  alias Kantele.World.InquiryHandlers.YelvqiJob

  @job_names ~w(打扫马房 锯木头 劈柴 浇菜地 锄草)

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      marks: Keyword.get(opts, :marks, %{}),
      temp: Keyword.get(opts, :temp, %{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{}),
      stats: %Stats{combat_exp: Keyword.get(opts, :combat_exp, 0)}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: "wuguan:guofu_dayuan2",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp data(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "yelvqi_job",
        config: %{},
        npc_name: "耶律齐",
        npc_room_id: "wuguan:guofu_dayuan2",
        asker_id: "player:test"
      },
      overrides
    )
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp character(conn), do: conn.private.update_character || conn.character

  defp session_conditions(conn) do
    (conn.session || %{})["conditions"] || %{}
  end

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert Kantele.World.InquiryHandlers.lookup("yelvqi_job") == YelvqiJob
    end

    test "asker 不匹配 → 静默（无输出）" do
      conn2 = YelvqiJob.run(conn(), %{}, data(%{asker_id: "player:other"}))
      assert out_text(conn2) == ""
    end

    test "已领活（job_name temp）→ 「还不快去做」" do
      conn2 = YelvqiJob.run(conn(temp: %{"job_name" => "打扫马房"}), %{}, data())
      assert out_text(conn2) =~ "你不是已经领了工作吗？还不快去做。"
    end

    test "combat_exp >= 40000 → 「闯荡江湖」" do
      conn2 = YelvqiJob.run(conn(combat_exp: 40_000), %{}, data())
      assert out_text(conn2) =~ "你功夫已经足够闯荡江湖，这里没有什么适合你的工作了。"
    end

    test "combat_exp < 40000 → 进入派活（不触发拒绝）" do
      conn2 = YelvqiJob.run(conn(combat_exp: 39_999), %{}, data())
      refute out_text(conn2) =~ "这里没有什么适合你的工作了"
      assert assigned_one_job?(character(conn2).meta.temp)
    end

    test "mark/guofu_out → 「怎么又回来了」" do
      conn2 = YelvqiJob.run(conn(temp: %{"mark/guofu_out" => 1}), %{}, data())
      assert out_text(conn2) =~ "你不是已经外出闯荡了吗，怎么又回来了？"
    end
  end

  describe "random 派活（assign_job）" do
    test "写 job_name temp（五种之一）+ 文案含该活计" do
      conn2 = YelvqiJob.run(conn(), %{}, data())
      temp = character(conn2).meta.temp
      text = out_text(conn2)

      assert assigned_one_job?(temp)
      target = temp["job_name"]
      assert target in @job_names
      assert text =~ "你先到物品房领工具，然后去后院「#{target}」吧。"
    end

    test "施加 wuguan_job 计时 condition（duration 4..6，落 session.conditions）" do
      conn2 = YelvqiJob.run(conn(), %{}, data())
      conds = session_conditions(conn2)

      assert Map.has_key?(conds, "wuguan_job")
      %{"duration" => d} = conds["wuguan_job"]
      assert d >= 4 and d <= 6
    end

    test "data 缺 asker_id → 不改 conn（不崩）" do
      conn2 = YelvqiJob.run(conn(), %{}, %{kind: "yelvqi_job"})
      assert out_text(conn2) == ""
    end
  end

  describe "Kantele.WuguanJob condition daemon" do
    test "daemon/1 解析 wuguan_job" do
      assert WuguanJob.daemon("wuguan_job") == {:ok, WuguanJob}
      assert WuguanJob.daemon("other") == :error
    end

    test "update_condition 每跳减一，< 1 到期" do
      assert WuguanJob.update_condition(%{"duration" => 1}) == {:expire}
      assert WuguanJob.update_condition(%{"duration" => 4}) == {:continue, %{"duration" => 3}}
      assert WuguanJob.update_condition(%{"duration" => 0}) == {:expire}
    end

    test "do_effect 为纯计时 no-op" do
      state = %{conditions: %{"wuguan_job" => %{"duration" => 5}}}
      assert WuguanJob.do_effect(state, "wuguan_job", nil) == {:ok, state}
    end
  end

  # LPC 真值语义：0/false/nil/"" 均为假。
  defp assigned_one_job?(temp) do
    case Map.get(temp, "job_name") do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      name when is_binary(name) -> name in @job_names
      _ -> false
    end
  end
end
