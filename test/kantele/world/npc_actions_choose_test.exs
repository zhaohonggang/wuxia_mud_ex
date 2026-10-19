defmodule Kantele.World.NpcActions.ChooseTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Choose

  @room_id "city:zhujuan"

  defp conn(stats, temp \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: %PlayerMeta{stats: stats, temp: temp}
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params, do: %{verb: "choose", trailing: "", room_id: @room_id, npc: %Kalevala.Character{name: "老板"}}

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
      assert :not_handled = Choose.run(conn(nil), params() |> Map.put(:room_id, nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled = Choose.run(conn(nil), params() |> Map.put(:room_id, "city:kedian"))
    end
  end

  describe "run/2（驭兽术守卫）" do
    test "stats 为 nil → 技能按 0 计 → 拒绝「驭兽术太低」" do
      conn2 = Choose.run(conn(nil), params())

      assert String.contains?(out_text(conn2), "你的驭兽术太低了，即使养了坐骑，也会离你而去")
    end

    test "training = 29（差 1）→ 仍拒绝" do
      conn2 = Choose.run(conn(%Stats{skills: %{"training" => 29}}), params())

      assert String.contains?(out_text(conn2), "驭兽术太低")
    end

    test "skills 为 nil 的裸 struct → 不崩溃，按 0 拒" do
      conn2 = Choose.run(conn(%Stats{}), params())

      assert String.contains?(out_text(conn2), "驭兽术太低")
    end

    test "training = 30 → 过守卫，落到报价 say" do
      conn2 = Choose.run(conn(%Stats{skills: %{"training" => 30}}), params())

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "每只宠物一百两黄金"))
    end
  end

  describe "run/2（pet/money 守卫）" do
    test "无 pet/money temp → say 报价（RANK_D 尊称按 Helpers.respect 落「大侠」）" do
      conn2 = Choose.run(conn(%Stats{skills: %{"training" => 50}}), params())

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "老板说道：这位大侠，每只宠物一百两黄金！"))
      # say 是广播；不推私聊
      assert out_text(conn2) == ""
    end

    test "pet/money = 0 → 按未付报价（LPC 0 为假）" do
      conn2 = Choose.run(conn(%Stats{skills: %{"training" => 50}}, %{"pet/money" => 0}), params())

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "每只宠物一百两黄金"))
    end

    test "pet/money 已付 → 静默消费（@todo 宠物定制链；原世界亦不可达）" do
      conn2 = Choose.run(conn(%Stats{skills: %{"training" => 50}}, %{"pet/money" => 1}), params())

      assert conn2 != :not_handled
      assert out_text(conn2) == ""
      assert vision_texts(conn2) == []
    end
  end
end
