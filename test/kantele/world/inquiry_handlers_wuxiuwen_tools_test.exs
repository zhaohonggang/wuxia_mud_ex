defmodule Kantele.World.InquiryHandlers.WuxiuwenToolsTest do
  @moduledoc """
  P5 打工闭环：武修文发工具问询（kind = "wuxiuwen_tools"），镜像 LPC
  `/d/wuguan/npc/wuxiuwen.c` `give_tools()`。

  覆盖：asker 守门 / 已发过 / 已还过 / 没领工 / 按活计发工具（落 mark/工具 +
  进背包 + 回话）；另含 InquiryHandlers 注册断言。工具定义落在 wuguan.ucl 的
  items 命名空间（全 id `wuguan:items.<key>`），测试用 Items.put 兜底确保可解析。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.WuxiuwenTools
  alias Kantele.World.Items

  # job_name → 工具全 id（与 WuxiuwenTools.@tool_for_job 保持一致）
  @job_tool %{
    "打扫马房" => "wuguan:items.saozhou",
    "锄草" => "wuguan:items.chutou",
    "浇菜地" => "wuguan:items.piao",
    "锯木头" => "wuguan:items.juzi",
    "劈柴" => "wuguan:items.chaidao"
  }

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    # 兜底：若测试环境未加载 wuguan.ucl 工具，则临时塞入；只清理自己加的。
    added =
      Enum.filter(Map.values(@job_tool), fn id ->
        case Items.get(id) do
          {:ok, _} -> false
          _ -> Items.put(id, %Item{id: id, name: id, verbs: [], callback_module: Kantele.World.Item, meta: %{}})
        end
      end)

    on_exit(fn ->
      for id <- added, do: Items.delete(id)
    end)

    :ok
  end

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      temp: Keyword.get(opts, :temp, %{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{}),
      stats: %Stats{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: "wuguan:guofu_dayuan2",
        inventory: [],
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp data(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "wuxiuwen_tools",
        config: %{},
        npc_name: "武修文",
        npc_room_id: "wuguan:wuxiuwen",
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

  defp temp_get(conn, key), do: PlayerMeta.get_temp(character(conn).meta, key)

  defp inventory_ids(conn), do: Enum.map(character(conn).inventory, & &1.item_id)

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert Kantele.World.InquiryHandlers.lookup("wuxiuwen_tools") == WuxiuwenTools
    end

    test "asker 不匹配 → 静默（无输出）" do
      conn2 = WuxiuwenTools.run(conn(), %{}, data(%{asker_id: "player:other"}))
      assert out_text(conn2) == ""
    end

    test "已发过工具（mark/工具）→ 「我已经给你了」" do
      conn2 = WuxiuwenTools.run(conn(temp: %{"mark/工具" => 1}), %{}, data())
      assert out_text(conn2) =~ "我不是已经给你了吗，怎么那么罗嗦？"
    end

    test "已还过工具（mark/还了）→ 「先去覆命」" do
      conn2 = WuxiuwenTools.run(conn(temp: %{"mark/还了" => 1}), %{}, data())
      assert out_text(conn2) =~ "你还是先到耶律师兄那覆命了再说吧。"
    end

    test "没领工（job_name 不在五种内）→ 「你又没领工作」" do
      conn2 = WuxiuwenTools.run(conn(temp: %{"job_name" => "别的活计"}), %{}, data())
      assert out_text(conn2) =~ "你又没有领工作，跑来要什么工具？"
    end
  end

  describe "按活计发工具" do
    test "五种活计各发对应工具：落 mark/工具 + 进背包 + 回话" do
      for {job, tool_id} <- @job_tool do
        conn2 = WuxiuwenTools.run(conn(temp: %{"job_name" => job}), %{}, data())

        assert temp_get(conn2, "mark/工具") == 1, "活计 #{job} 未置 mark/工具"
        assert tool_id in inventory_ids(conn2), "活计 #{job} 未发工具 #{tool_id}"

        text = out_text(conn2)
        assert text =~ "武修文交给你一把工具。" and text =~ "东西交给你了，可要小心保管，别弄丢了。"
      end
    end

    test "data 缺 asker_id → 不改 conn（不崩）" do
      conn2 = WuxiuwenTools.run(conn(), %{}, %{kind: "wuxiuwen_tools"})
      assert out_text(conn2) == ""
    end
  end
end
