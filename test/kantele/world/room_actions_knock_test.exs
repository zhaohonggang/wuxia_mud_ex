defmodule Kantele.World.RoomActions.DoKnockTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `DoPushTest.FakeRoom`）。

  除 `data.state`（`RestKnock` 的 `sleeping_person` 读写、`DynamicExit` 的出口与
  定时器 ref）外，额外提供 `set_occupants/2` 模拟邻居房有人（等价 LPC
  `person_inside`）。
  """
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  def reset(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, :reset)
      _ -> :ok
    end
  end

  def set_occupants(room_id, chars) when is_list(chars) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, {:set_occupants, chars})
      _ -> :ok
    end
  end

  @impl true
  def init({room_id, _opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok,
     %{
       data: %Kantele.World.Room{id: state.data.id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end

  def handle_call({:set_occupants, chars}, _from, state) do
    {:reply, :ok, %{state | private: %{state.private | characters: chars}}}
  end
end

defmodule Kantele.World.RoomActions.DoKnockTest do
  @moduledoc """
  P5-6 门/容器收尾批：4 处 `do_knock` 的移植测试。

  覆盖点：
  - 注册：4 房都挂 `do_knock`，且 `guanwai:jingxiu` / `huashan:xiaolu2` /
    `hengyang:liufugate` 的 `do_push` 未被覆盖（合并进同一房间条目）。
  - 休息室敲门（`RestKnock`）：错词提示 / 门已开提示 / 空房「咚、咚、咚」+
    邻居房收到「外面传来一阵敲门声」/ 有人时二选一文案 / `sleeping_person`
    （语料死分支）直接写房间状态也可命中，且 else 分支读完即清。
  - 刘府敲门：不校验宾语、写 `marks/liufu`、随后 `push gate` 可开门（闭环）。
  - 揽月居暗语：错词提示 / 重复敲「别敲了！」/ 排程 `check_pass`（4s）与
    `end_whisper`（9s）的 effect 载荷（直接调 `fire_*`，不等定时器）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DoKnockTest.FakeRoom
  alias Kantele.World.RoomActions.DynamicExit

  alias Kantele.World.RoomActions.Guanwai.Jingxiu.Knock, as: GuanwaiJingxiuKnock
  alias Kantele.World.RoomActions.Hengyang.Liufugate.Knock, as: LiufugateKnock
  alias Kantele.World.RoomActions.Hengyang.Liufugate.Push, as: LiufugatePush
  alias Kantele.World.RoomActions.Huashan.Xiaolu2.Knock, as: HuashanXiaolu2Knock
  alias Kantele.World.RoomActions.Yanziwu.Lanyue.Knock, as: LanyueKnock

  @rooms [
    "guanwai:jingxiu",
    "guanwai:xiuxishi",
    "huashan:xiaolu2",
    "huashan:xiuxishi",
    "hengyang:liufugate",
    "hengyang:liufudayuan",
    "yanziwu:lanyue"
  ]

  setup_all do
    pids =
      for room_id <- @rooms do
        :global.unregister_name({Kalevala.World.Room, room_id})
        {:ok, pid} = FakeRoom.start_link({room_id, []})
        pid
      end

    on_exit(fn ->
      Enum.each(pids, fn pid ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)
    end)

    :ok
  end

  setup do
    Enum.each(@rooms, &FakeRoom.reset/1)
    :ok
  end

  # ---- 注册表 ----

  describe "注册表" do
    test "4 个房间都挂了 do_knock" do
      for room_id <- ~w(guanwai:jingxiu huashan:xiaolu2 hengyang:liufugate yanziwu:lanyue) do
        assert RoomActionHandlers.registered?(room_id, "do_knock")
      end
    end

    test "同房的 do_push 仍注册（未被 knock 条目覆盖）" do
      for room_id <- ~w(guanwai:jingxiu huashan:xiaolu2 hengyang:liufugate) do
        assert RoomActionHandlers.registered?(room_id, "do_push")
      end
    end
  end

  # ---- 休息室敲门：guanwai:jingxiu / huashan:xiaolu2（RestKnock 共享）----

  describe "guanwai:jingxiu do_knock（south → guanwai:xiuxishi）" do
    test "错词（非 door/men）→ 提示「你要敲什么？」" do
      conn = GuanwaiJingxiuKnock.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "wall"))

      assert output_text(conn) =~ "你要敲什么？"
      assert published(conn) == []
    end

    test "门已开 → 提示「大门已经是开着了。」，不播文案" do
      Room.set_exit("guanwai:jingxiu", "south", "guanwai:xiuxishi")

      conn = GuanwaiJingxiuKnock.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "men"))

      assert output_text(conn) =~ "大门已经是开着了。"
      assert published(conn) == []
    end

    test "休息室空着 → 「咚、咚、咚」+ 邻居房收到「外面传来一阵敲门声」" do
      conn =
        GuanwaiJingxiuKnock.run(
          conn("guanwai:jingxiu"),
          params("guanwai:jingxiu", "men")
        )

      assert output_text(conn) == ""
      assert [vision] = published(conn)
      assert vision =~ "{npc}轻轻地敲了敲门：咚、咚、咚．．．咚、咚、咚．．．"
    end

    test "休息室有人 → 二选一文案（不耐幪 / 踱来踱去）" do
      FakeRoom.set_occupants("guanwai:xiuxishi", [%Kalevala.Character{id: "sleeper"}])

      conn =
        GuanwaiJingxiuKnock.run(
          conn("guanwai:jingxiu"),
          params("guanwai:jingxiu", "door")
        )

      assert output_text(conn) == ""
      assert [vision] = published(conn)

      assert vision =~
               "{npc}轻轻地敲了敲门，只听见里面有人很不耐烦地吼到：\n刚躺下就来敲门！我睡着了，听不见！！！" or
               vision =~
                 "{npc}轻轻地敲了敲门，只听见里面有些响动，\n好象有人在踱来踱去，拿不定主意是否开门。"
    end

    test "sleeping_person 房间状态 > 0 → 鼾声文案（语料无 setter 的死分支，直接置状态验证）" do
      Room.put_state_by_id("guanwai:xiuxishi", "sleeping_person", 1)

      conn =
        GuanwaiJingxiuKnock.run(
          conn("guanwai:jingxiu"),
          params("guanwai:jingxiu", "men")
        )

      assert output_text(conn) == ""

      assert [vision] = published(conn)

      assert vision =~
               "{npc}刚轻轻地敲了一下门，就听见里面传出一阵雷鸣般的鼾声，\n显然里面的人睡得跟死猪似的，怎么敲都没用了"

      # 该分支不清理 sleeping_person（LPC 只在 else 分支 delete_temp）
      assert Room.get_state_by_id("guanwai:xiuxishi", "sleeping_person") == 1
    end

    test "else 分支读完即清 sleeping_person（LPC delete_temp）" do
      Room.put_state_by_id("guanwai:xiuxishi", "sleeping_person", 0)

      _conn =
        GuanwaiJingxiuKnock.run(
          conn("guanwai:jingxiu"),
          params("guanwai:jingxiu", "men")
        )

      assert Room.get_state_by_id("guanwai:xiuxishi", "sleeping_person") == nil
    end
  end

  describe "huashan:xiaolu2 do_knock（east → huashan:xiuxishi）" do
    test "空房敲门走 east 出口判定 + 播同一套文案" do
      conn =
        HuashanXiaolu2Knock.run(
          conn("huashan:xiaolu2"),
          params("huashan:xiaolu2", "men")
        )

      assert [vision] = published(conn)
      assert vision =~ "{npc}轻轻地敲了敲门：咚、咚、咚．．．咚、咚、咚．．．"

      # east 开着才提示「已经开着了」（方向与 guanwai 版不同）
      Room.set_exit("huashan:xiaolu2", "east", "huashan:xiuxishi")
      conn = HuashanXiaolu2Knock.run(conn("huashan:xiaolu2"), params("huashan:xiaolu2", "men"))
      assert output_text(conn) =~ "大门已经是开着了。"
    end

    test "邻居房收到含玩家名的纯文本" do
      subscribe_room("huashan:xiuxishi")

      _conn =
        HuashanXiaolu2Knock.run(
          conn("huashan:xiaolu2"),
          params("huashan:xiaolu2", "door")
        )

      assert_receive {:room_message,
                      "外面传来一阵敲门声，你从门缝往外一瞧，是玩家一脸焦急地站在门外，\n看样子也想进来休息。\n"},
                     500
    end
  end

  # ---- hengyang:liufugate：knock 写 marks/liufu → push gate 开门（闭环）----

  describe "hengyang:liufugate do_knock" do
    test "不校验宾语：knock 任何对象都敲门 + 写 marks/liufu" do
      conn = LiufugateKnock.run(conn("hengyang:liufugate"), params("hengyang:liufugate", "gate"))

      assert [vision] = published(conn)
      assert vision =~ "地敲着门，可里面却一点动静都没有"
      assert output_text(conn) == ""
      assert applied(conn).meta.temp["marks/liufu"] == 1

      # 无宾语也照样敲（LPC 无 arg 判断）
      conn = LiufugateKnock.run(conn("hengyang:liufugate"), params("hengyang:liufugate", ""))
      assert [vision] = published(conn)
      assert vision =~ "地敲着门"
    end

    test "knock 之后 push gate 能开门（此前无人写 marks，门永远打不开）" do
      conn = LiufugateKnock.run(conn("hengyang:liufugate"), params("hengyang:liufugate", "gate"))
      character = applied(conn)

      conn =
        char_conn(character)
        |> then(&LiufugatePush.run(&1, params("hengyang:liufugate", "gate")))

      refute conn == :not_handled
      assert DynamicExit.open?("hengyang:liufugate", "enter")
      assert exit_target("hengyang:liufugate", "enter") == "hengyang:liufudayuan"
    end
  end

  # ---- yanziwu:lanyue：暗语谜题入口 ----

  describe "yanziwu:lanyue do_knock" do
    test "错词（非 penjing）→ 提示「你要敲什么？」" do
      conn = LanyueKnock.run(conn("yanziwu:lanyue"), params("yanziwu:lanyue", "men"))

      assert output_text(conn) =~ "你要敲什么？"
      assert applied(conn).meta.temp["marks/pen"] == nil
    end

    test "knock penjing → 置 marks/pen + 文案；再敲 → 「别敲了！」" do
      conn = LanyueKnock.run(conn("yanziwu:lanyue"), params("yanziwu:lanyue", "penjing"))

      assert output_text(conn) =~ "你在盆景上敲了几下..."
      assert applied(conn).meta.temp["marks/pen"] == 1

      conn =
        char_conn(applied(conn))
        |> then(&LanyueKnock.run(&1, params("yanziwu:lanyue", "penjing")))

      assert output_text(conn) =~ "别敲了！"
    end

    test "fire_check_pass：两段文本 + set_temp can_whisper" do
      LanyueKnock.fire_check_pass(self())

      assert_receive %Event{topic: "trap/effect", data: %{effects: effects}}, 500

      texts = for {:text, text} <- effects, do: text
      assert texts == ["不一会儿，只听不远处隐约传来一阵说话声：“洒国梦语…”\n", "你想了想，觉得像是一句暗语，你很想回答(whisper)但又不知道说些什么！\n"]
      assert {:set_temp, "can_whisper", 1} in effects
    end

    test "fire_end_whisper：文本 + 清理两枚临时标记" do
      LanyueKnock.fire_end_whisper(self())

      assert_receive %Event{topic: "trap/effect", data: %{effects: effects}}, 500

      assert [{:text, "过了良久，只听见一阵不耐烦的声音传来：“算了，没事别在这来捣乱。”\n"},
              {:delete_temp, "marks/pen"},
              {:delete_temp, "can_whisper"}] = effects
    end
  end

  # ---- helpers ----

  defp conn(room_id, opts \\ []) do
    character = %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      pid: Keyword.get(opts, :pid, nil),
      room_id: room_id,
      attributes: %{},
      meta: %PlayerMeta{temp: Keyword.get(opts, :temp, %{})},
      inventory: []
    }

    char_conn(character)
  end

  defp char_conn(character) do
    %Conn{
      character: character,
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp params(room_id, arg), do: %{trailing: arg, room_id: room_id, verb: "knock"}

  defp applied(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %{data: data} when is_binary(data) -> data
      %Conn.Text{data: data} -> data
      other -> inspect(other)
    end)
    |> Enum.join()
  end

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, message, _opts, _err} -> message.data.text end)
  end

  defp subscribe_room(room_id) do
    channel = "rooms:#{room_id}"

    case Kantele.Communication.register(channel, Kantele.RoomChannel, room_id: room_id) do
      :ok -> :ok
      {:error, :already_registered} -> :ok
    end

    :ok =
      Kantele.Communication.subscribe(channel,
        character: %Kalevala.Character{id: "test-subscriber", room_id: room_id}
      )
  end

  defp exit_target(room_id, dir) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        pid
        |> :sys.get_state()
        |> Map.get(:data)
        |> Map.get(:exits)
        |> List.wrap()
        |> Enum.find_value(fn exit ->
          if Map.get(exit, :exit_name) == dir, do: Map.get(exit, :end_room_id)
        end)

      _ ->
        nil
    end
  end
end
