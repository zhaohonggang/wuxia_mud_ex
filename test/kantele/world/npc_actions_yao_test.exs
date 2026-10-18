defmodule Kantele.World.NpcActions.YaoTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Yao

  defp npc(name), do: %Kalevala.Character{name: name}

  defp conn(room_id, meta_opts \\ %{}, attrs \\ %{}) do
    meta = struct(%PlayerMeta{}, meta_opts)

    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: room_id,
        attributes: attrs,
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, npc, trailing \\ "") do
    %{verb: "yao", trailing: trailing, room_id: room_id, npc: npc}
  end

  # 引擎在每条命令后会应用 `private.update_character`；测试里手动折叠，模拟
  # 多命令间的会话态累积（temp 计数等）。
  defp run(conn, params) do
    case Yao.run(conn, params) do
      :not_handled -> :not_handled
      conn2 -> apply_updates(conn2)
    end
  end

  defp apply_updates(%Conn{} = conn) do
    case conn.private.update_character do
      nil -> conn
      character -> %{conn | character: character}
    end
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  describe "run/2 分派" do
    test "未注册房间 → :not_handled" do
      npc = npc("钱正伦")
      assert :not_handled = Yao.run(conn("unknown:room"), params("unknown:room", npc))
    end

    test "room_id 为 nil → :not_handled（不崩溃）" do
      npc = npc("钱正伦")
      assert :not_handled = Yao.run(conn(nil), params(nil, npc))
    end
  end

  describe "黄真（xiangyang:qianzhuang）" do
    test "失信商人（bad_vendor）→ 拒绝" do
      npc = npc("黄真")
      conn = conn("xiangyang:qianzhuang", %{env: %{"bad_vendor" => true}})

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))
      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "走开，走开")
    end

    test "非商会成员（无 is_vendor）→ 没理你" do
      npc = npc("黄真")
      conn = conn("xiangyang:qianzhuang")

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))
      assert String.contains?(out_text(conn2), "没理你")
    end

    test "刚领过（temp shang-ling）→ 拒绝" do
      npc = npc("黄真")

      conn =
        conn("xiangyang:qianzhuang", %{env: %{"is_vendor" => true}, temp: %{"shang-ling" => 1}})

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))
      assert String.contains?(out_text(conn2), "刚才我不是才给了你")
    end

    test "已开店（stall）→ 拒绝" do
      npc = npc("黄真")
      conn = conn("xiangyang:qianzhuang", %{env: %{"is_vendor" => true}, stall: %{"stock" => 1}})

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))
      assert String.contains?(out_text(conn2), "已经开店")
    end

    test "合格商人 → 设 temp 并 say" do
      npc = npc("黄真")
      conn = conn("xiangyang:qianzhuang", %{env: %{"is_vendor" => true}})

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))
      assert conn2 != :not_handled
      assert conn2.character.meta.temp["shang-ling"] == 1
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "吃饭的家伙"))
    end
  end

  describe "田嫂（wudu:chufang）" do
    test "先广播“开饭了吗”，未饱则发包子并广播“慢点吃”" do
      npc = npc("田嫂")
      conn = conn("wudu:chufang", %{stats: %Kantele.Character.Stats{str: 10}})

      conn2 = run(conn, params("wudu:chufang", npc))
      texts = vision_texts(conn2)
      assert Enum.any?(texts, &String.contains?(&1, "开饭了吗"))
      assert Enum.any?(texts, &String.contains?(&1, "慢点吃"))
    end

    test "已吃饱（food >= 90%）→ 拒绝" do
      npc = npc("田嫂")
      # 容量 = str*10+100 = 200，90% = 180
      meta_opts = %{stats: %Kantele.Character.Stats{str: 10}, vitals: %{food: 190}}
      conn = conn("wudu:chufang", meta_opts)

      conn2 = run(conn, params("wudu:chufang", npc))
      assert String.contains?(out_text(conn2), "等开饭时再来吧")
    end
  end

  describe "钱正伦（beijing:bingqi）" do
    setup do
      Kantele.World.NpcActions.Counters.reset("beijing:bingqi")
      Kantele.World.NpcActions.Counters.put_total("beijing:bingqi", 100)
      :ok
    end

    test "无参数 → 提示要什么" do
      npc = npc("钱正伦")
      conn = conn("beijing:bingqi", %{family: %{name: "八卦门"}})

      conn2 = run(conn, params("beijing:bingqi", npc, ""))
      assert String.contains?(out_text(conn2), "你要什么东西")
    end

    test "非八卦门 → 拒绝" do
      npc = npc("钱正伦")
      conn = conn("beijing:bingqi", %{family: %{name: "丐帮"}})

      conn2 = run(conn, params("beijing:bingqi", npc, "blade"))
      assert String.contains?(out_text(conn2), "只有镖局里的人")
    end

    test "非法 arg → 拒绝" do
      npc = npc("钱正伦")
      conn = conn("beijing:bingqi", %{family: %{name: "八卦门"}})

      conn2 = run(conn, params("beijing:bingqi", npc, "foo"))
      assert String.contains?(out_text(conn2), "我这里没有")
    end

    test "兵器领满 3 件后再领 → 拒绝" do
      npc = npc("钱正伦")
      conn = conn("beijing:bingqi", %{family: %{name: "八卦门"}})

      conn =
        Enum.reduce(1..3, conn, fn _i, c ->
          run(c, params("beijing:bingqi", npc, "blade"))
        end)

      conn2 = run(conn, params("beijing:bingqi", npc, "blade"))
      assert String.contains?(out_text(conn2), "兵器，还不够")
    end

    test "护甲领满 3 件后再领 → 拒绝" do
      npc = npc("钱正伦")
      conn = conn("beijing:bingqi", %{family: %{name: "八卦门"}})

      conn =
        Enum.reduce(1..3, conn, fn _i, c ->
          run(c, params("beijing:bingqi", npc, "body"))
        end)

      conn2 = run(conn, params("beijing:bingqi", npc, "body"))
      assert String.contains?(out_text(conn2), "护甲，还不够")
    end

    test "兵器与护甲计数互不影响" do
      npc = npc("钱正伦")
      conn = conn("beijing:bingqi", %{family: %{name: "八卦门"}})

      conn =
        Enum.reduce(1..3, conn, fn _i, c ->
          run(c, params("beijing:bingqi", npc, "blade"))
        end)

      # 兵器满，但护甲仍可领（计数独立）；无 cache 时退回“没有”，关键是不报护甲满
      conn2 = run(conn, params("beijing:bingqi", npc, "body"))
      refute String.contains?(out_text(conn2), "护甲，还不够")
    end
  end
end
