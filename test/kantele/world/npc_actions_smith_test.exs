defmodule Kantele.World.NpcActions.SmithTest do
  @moduledoc """
  P5-9：襄阳铁匠打工动词 `gu` / `dapi` / `cuihuo` 与修理动词
  `repair` / `xiuli`（`/inherit/char/smith.c`）。

  覆盖：分派守门 / 未领活斥责广播 / reward 全量结算（工钱+经验+潜能+
  mark+掉气+忙乱+清 temp）/ is_busy 守卫 / repair 两段确认链（无参、
  无物、无 consistence、报价、确认扣钱修好、钱不够、忙乱、已完好）。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.Smith

  @room_id "xiangyang:tiejiangpu"

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100}),
      temp: Keyword.get(opts, :temp, %{}),
      marks: Keyword.get(opts, :marks, %{}),
      coins: Keyword.get(opts, :coins, 1_000),
      combat: Keyword.get(opts, :combat, %Combat{})
    }

    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: meta,
        inventory: Keyword.get(opts, :inventory, [])
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(verb, trailing \\ ""),
    do: %{verb: verb, trailing: trailing, room_id: @room_id, npc: %Kalevala.Character{name: "铁匠"}}

  defp character(conn), do: conn.private.update_character || conn.character

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  # 带 consistence 的长剑实例（实例已挂定义，绕开世界缓存）
  defp sword_instance(meta \\ %{}) do
    %Item.Instance{
      id: "inst-1",
      item_id: "clone_lib:changjian",
      created_at: ~U[2026-01-01 00:00:00Z],
      meta: meta,
      item: %Item{
        id: "clone_lib:changjian",
        name: "长剑",
        description: "test",
        meta: %{"value" => 1000, "unit" => "柄"}
      }
    }
  end

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Smith.run(conn(), params("gu") |> Map.put(:room_id, nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled = Smith.run(conn(), params("gu") |> Map.put(:room_id, "city:kedian"))
    end

    test "未注册 verb（ask）→ :not_handled" do
      assert :not_handled = Smith.run(conn(), params("ask"))
    end
  end

  describe "gu/dapi/cuihuo：未领活斥责（房间可见）" do
    test "gu 未领 → 广播「滚开，乱搞什么」且无私聊" do
      conn2 = Smith.run(conn(), params("gu"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "滚开，乱搞什么"))
      assert out_text(conn2) == ""
    end

    test "dapi 未领 → 广播「放下，乱搞什么」" do
      conn2 = Smith.run(conn(), params("dapi"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "放下，乱搞什么"))
    end

    test "cuihuo 未领 → 广播「别给我搞坏了」" do
      conn2 = Smith.run(conn(), params("cuihuo"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "别给我搞坏了"))
    end

    test "领了别的活计仍算未领（LPC 按 temp 键分别判）" do
      conn2 = Smith.run(conn(temp: %{"smith/dapi" => 1}), params("gu"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "滚开，乱搞什么"))
    end
  end

  describe "gu：已领活 → 干活 + reward 结算" do
    setup do
      conn2 =
        Smith.run(
          conn(temp: %{"smith/gu" => 1}, coins: 0, marks: %{"mark/job_smith" => 7}),
          params("gu")
        )

      {:ok, conn: conn2}
    end

    test "广播干活 vision", %{conn: conn2} do
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "拉起鼓风机拼命鼓了起来"))
    end

    test "三个 smith/* temp 全部清除", %{conn: conn2} do
      temp = character(conn2).meta.temp
      assert temp["smith/gu"] == nil
      assert temp["smith/dapi"] == nil
      assert temp["smith/cuihuo"] == nil
    end

    test "工钱 50~99 文入账（coins 0 起步）", %{conn: conn2} do
      assert character(conn2).meta.coins in 50..99
    end

    test "经验 +20~29、潜能 +10~19", %{conn: conn2} do
      stats = character(conn2).meta.stats
      assert stats.combat_exp in 20..29
      assert stats.potential in 10..19
    end

    test "mark/job_smith 递增（持久 marks）", %{conn: conn2} do
      assert character(conn2).meta.marks["mark/job_smith"] == 8
    end

    test "掉气 30~49（qi 100 起步）", %{conn: conn2} do
      assert character(conn2).meta.vitals.qi in 51..70
    end

    test "start_busy(3)", %{conn: conn2} do
      assert character(conn2).meta.combat.busy == 3
    end

    test "工钱广播 + 到账/经验文案", %{conn: conn2} do
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "干得不坏，这是给你的工钱"))
      assert out_text(conn2) =~ "点经验和"
      assert out_text(conn2) =~ "文铜钱"
    end
  end

  describe "is_busy 守卫" do
    test "忙乱中 → 「你现在正忙。」且不结算" do
      conn2 =
        Smith.run(
          conn(temp: %{"smith/gu" => 1}, combat: %Combat{busy: 2}, coins: 0),
          params("gu")
        )

      assert out_text(conn2) =~ "你现在正忙"
      # 状态零变更：temp 仍在、coins 未入账
      assert character(conn2).meta.temp["smith/gu"] == 1
      assert character(conn2).meta.coins == 0
    end
  end

  describe "dapi/cuihuo：已领活干活 vision" do
    test "dapi → 「用力敲打着」并结算" do
      conn2 = Smith.run(conn(temp: %{"smith/dapi" => 1}), params("dapi"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "用力敲打着"))
      assert character(conn2).meta.marks["mark/job_smith"] == 1
    end

    test "cuihuo → 「伸进了水池」并结算" do
      conn2 = Smith.run(conn(temp: %{"smith/cuihuo" => 1}), params("cuihuo"))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "伸进了水池"))
      assert character(conn2).meta.marks["mark/job_smith"] == 1
    end
  end

  describe "repair/xiuli 两段确认链" do
    test "无参 → 「你打算修理什么对象？」" do
      conn2 = Smith.run(conn(), params("repair", ""))

      assert out_text(conn2) =~ "你打算修理什么对象？"
    end

    test "xiuli 同 handler（无参同样提示）" do
      conn2 = Smith.run(conn(), params("xiuli", ""))

      assert out_text(conn2) =~ "你打算修理什么对象？"
    end

    test "背包无此物 → 「你身上好像没有这样东西。」" do
      conn2 = Smith.run(conn(), params("repair", "长剑"))

      assert out_text(conn2) =~ "你身上好像没有这样东西"
    end

    test "物品无 consistence → 「似乎不需要在这里修理吧？」" do
      conn2 = Smith.run(conn(inventory: [sword_instance()]), params("repair", "长剑"))

      assert out_text(conn2) =~ "似乎不需要在这里修理吧？"
    end

    test "consistence 100 → 「现在完好无损，修理做什么？」" do
      conn2 =
        Smith.run(
          conn(inventory: [sword_instance(%{"consistence" => 100})]),
          params("repair", "长剑")
        )

      assert out_text(conn2) =~ "现在完好无损，修理做什么？"
    end

    test "consistence 50 → 报价 + 落 pending + 提示再输一次" do
      conn2 =
        Smith.run(
          conn(inventory: [sword_instance(%{"consistence" => 50})]),
          params("repair", "长剑")
        )

      # cost = (120-50)*1000/480 = 145 → 百档取整 140
      assert character(conn2).meta.temp["smith/repair"] == %{"item" => "inst-1", "cost" => 140}
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "要修好它得要"))
      assert out_text(conn2) =~ "请再输入一次这条命令"
    end

    test "确认（第二次 repair）→ 扣钱 + consistence 归 100 + 忙乱 + 清 pending" do
      conn2 =
        Smith.run(
          conn(
            inventory: [sword_instance(%{"consistence" => 50})],
            temp: %{"smith/repair" => %{"item" => "inst-1", "cost" => 140}},
            coins: 1_000
          ),
          params("repair", "长剑")
        )

      character = character(conn2)
      assert character.meta.coins == 860
      assert character.meta.temp["smith/repair"] == nil

      fixed = Enum.find(character.inventory, &(&1.id == "inst-1"))
      assert fixed.meta["consistence"] == 100
      assert character.meta.combat.busy in 1..5

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "东敲西补"))
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "随手把长剑还给了"))
    end

    test "确认但钱不够 → 「你身上的钱不够呀！」" do
      conn2 =
        Smith.run(
          conn(
            inventory: [sword_instance(%{"consistence" => 50})],
            temp: %{"smith/repair" => %{"item" => "inst-1", "cost" => 140}},
            coins: 139
          ),
          params("repair", "长剑")
        )

      assert out_text(conn2) =~ "你身上的钱不够呀"
      assert character(conn2).meta.coins == 139
    end

    test "确认但忙乱 → 「你现在正忙着呢！」" do
      conn2 =
        Smith.run(
          conn(
            inventory: [sword_instance(%{"consistence" => 50})],
            temp: %{"smith/repair" => %{"item" => "inst-1", "cost" => 140}},
            combat: %Combat{busy: 1}
          ),
          params("repair", "长剑")
        )

      assert out_text(conn2) =~ "你现在正忙着呢"
    end

    test "pending 指向别的实例 → 重新报价（不确认）" do
      conn2 =
        Smith.run(
          conn(
            inventory: [sword_instance(%{"consistence" => 50})],
            temp: %{"smith/repair" => %{"item" => "other-inst", "cost" => 140}}
          ),
          params("repair", "长剑")
        )

      assert out_text(conn2) =~ "请再输入一次这条命令"
      assert character(conn2).meta.temp["smith/repair"]["item"] == "inst-1"
    end
  end
end
