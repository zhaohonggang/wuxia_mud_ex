defmodule Kantele.World.InquiryHandlers.QuestTest do
  @moduledoc """
  明教 #948/#955：张无忌 "历练"/"历炼"/"锻炼" → kind="quest" 问询 handler。
  LPC 依据：`kungfu/class/mingjiao/zhangwuji.c:158-162`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Loader}
  alias Kantele.World.InquiryHandlers.Quest

  setup_all do
    %{world: Loader.load()}
  end

  setup do
    :ok
  end

  defp conn(overrides \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(overrides, :stats, %Stats{shen: -10000}),
      vitals: %Vitals{qi: 100, max_qi: 100},
      env: %{},
      family: %{name: "明教", master_id: "mingjiao_zhangwuji"},
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "mingjiao:dadian",
        inventory: Keyword.get(overrides, :inventory, []),
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp cfg(overrides \\ %{}) do
    %{
      "kind" => "quest",
      "file" => "mingjiao_lilian",
      "master_name" => "张无忌",
      "master_id" => "mingjiao_zhangwuji",
      "place" => "明教大殿"
    }
    |> Map.merge(overrides)
  end

  defp data(overrides) do
    %{
      kind: "quest",
      config: cfg(),
      npc_id: "mingjiao_zhangwuji",
      npc_name: "张无忌",
      npc_room_id: "mingjiao:dadian",
      asker_id: "player:test",
      asker_name: "测试玩家",
      owner: nil
    }
    |> Map.merge(Map.new(overrides))
  end

  defp run(c, overrides \\ []), do: Quest.run(c, cfg(), data(overrides))

  defp out_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} when is_binary(data) -> data
      %Conn.EventText{text: %Conn.Text{data: iodata}} -> IO.iodata_to_binary(iodata)
      _ -> ""
    end)
    |> Enum.join()
  end

  defp character(conn), do: conn.private.update_character || conn.character

  describe "UCL 数据落地" do
    test "张无忌 历练/历炼/锻炼 指向 kind=quest 且携带 file", %{world: world} do
      zhangwuji = Enum.find(world.characters, &(&1.name == "张无忌"))

      assert zhangwuji.meta.inquiries["历练"]["kind"] == "quest"
      assert zhangwuji.meta.inquiries["历练"]["file"] == "mingjiao_lilian"

      assert zhangwuji.meta.inquiries["历炼"]["kind"] == "quest"
      assert zhangwuji.meta.inquiries["历炼"]["file"] == "mingjiao_lilian"

      assert zhangwuji.meta.inquiries["锻炼"]["kind"] == "quest"
      assert zhangwuji.meta.inquiries["锻炼"]["file"] == "mingjiao_lilian"
    end

    test "quest kind 已注册" do
      assert InquiryHandlers.lookup("quest") == Kantele.World.InquiryHandlers.Quest
    end
  end

  describe "任务接取" do
    test "首次接取 → 登记到 meta.quests.todo 并渲染接受文案" do
      conn2 = run(conn())

      assert out_text(conn2) =~ "张无忌道：「好，这mingjiao_lilian之事便托付给你了，务必小心。」"

      quests = PlayerMeta.quests(character(conn2).meta)
      assert Map.has_key?(quests.todo, "mingjiao_lilian")
      assert quests.todo["mingjiao_lilian"].meta.master_name == "张无忌"
      assert quests.todo["mingjiao_lilian"].meta.place == "明教大殿"
    end

    test "重复接取（同一任务在办中）→ :duplicate 文案" do
      # 预先把任务塞进 todo，模拟已在办
      c0 = conn()
      state0 = PlayerMeta.quests(c0.character.meta)
      state1 = Kantele.Quest.set_todo(state0, %{file: "mingjiao_lilian", kill: [], item: []})
      {:ok, state1} = state1
      meta1 = PlayerMeta.put_quests(c0.character.meta, state1)
      c1 = %Conn{
        c0
        | character: %{c0.character | meta: meta1}
      }

      conn2 = run(c1)
      assert out_text(conn2) =~ "这差事你已在办，何必再问？"
    end

    test "无效 spec（缺 file）→ :invalid 文案" do
      c = conn()
      conn2 = Quest.run(c, %{"kind" => "quest"}, data(%{}))
      assert out_text(conn2) =~ "这差事不似真的，恕老夫不相托付。"
    end
  end

  describe "边界" do
    test "非提问者的回执 → conn 不变" do
      c = conn()
      assert c == Quest.run(c, cfg(), data(asker_id: "player:other"))
    end

    test "非 map data → 返回 conn 不变" do
      c = conn()
      assert c == Quest.run(c, cfg(), "not a map")
    end

    test "非 map config → 返回 conn 不变" do
      c = conn()
      assert c == Quest.run(c, "not a map", data(%{}))
    end
  end
end
