defmodule Kantele.World.RoomActions.Yanziwu.Lanyue.SayTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 DoKnockTest.FakeRoom）。
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
    {:reply, :ok,
     %{
       data: %Kantele.World.Room{id: state.data.id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.Yanziwu.Lanyue.SayTest do
  @moduledoc """
  P5-6 收尾：揽月居暗语谜题 `do_say`（whisper）移植测试。

  覆盖点：
  - 注册表：`yanziwu:lanyue` 的 `do_say` → `Say.run`
  - 无 `can_whisper` 标记 → `:not_handled`（放行全局 `do_say`）
  - 有 `can_whisper=1`，答对「光复大燕」 → 清标记 + 传送 `yanziwu:huanshi`
  - 有 `can_whisper=1`，答错 → `:not_handled`，标记保留
  - 有 `can_whisper=1`，空字符串 → `:not_handled`
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Yanziwu.Lanyue.Say
  alias Kantele.World.RoomActions.Yanziwu.Lanyue.SayTest.FakeRoom

  @room "yanziwu:lanyue"
  @target "yanziwu:huanshi"
  @phrase "光复大燕"

  setup_all do
    :global.unregister_name({Kalevala.World.Room, @room})
    {:ok, _pid} = FakeRoom.start_link({@room, []})
    on_exit(fn ->
      pid = :global.whereis_name({Kalevala.World.Room, @room})
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)
    :ok
  end

  setup do
    FakeRoom.reset(@room)
    :ok
  end

  # ---- 注册表 ----

  describe "注册表" do
    test "do_say 指向 Say" do
      assert RoomActionHandlers.lookup(@room, "do_say") ==
               {:ok, {Say, :run}}
    end

    test "非本房 → :not_handled" do
      conn = conn("yanziwu:huanshi")

      assert Say.run(conn, %{verb: "do_say", trailing: @phrase, room_id: "yanziwu:huanshi"}) ==
               :not_handled
    end

    test "无角色上下文 → :not_handled" do
      assert Say.run(%Conn{}, %{verb: "do_say", trailing: @phrase, room_id: @room}) ==
               :not_handled
    end
  end

  # ---- do_say 消费 ----

  describe "do_say" do
    test "无 can_whisper → :not_handled，不传送" do
      result = run_say(@phrase, conn(@room, temp: %{}))

      assert result == :not_handled
    end

    test "有 can_whisper=1，答对「光复大燕」 → 清标记、传送 huanshi" do
      result = run_say(@phrase, conn(@room, temp: %{"can_whisper" => 1}))

      refute result == :not_handled
      assert Map.get(result.private.update_character.meta.temp, "can_whisper") == nil
      assert result.private.update_character.room_id == @target
    end

    test "有 can_whisper=1，答错 → :not_handled，标记保留" do
      result = run_say("不是暗语", conn(@room, temp: %{"can_whisper" => 1}))

      assert result == :not_handled
    end

    test "有 can_whisper=1，空字符串 → :not_handled" do
      result = run_say("", conn(@room, temp: %{"can_whisper" => 1}))

      assert result == :not_handled
    end

    test "有 can_whisper=1，前后空格答对 → 传送" do
      result = run_say("  #{@phrase}  ", conn(@room, temp: %{"can_whisper" => 1}))

      refute result == :not_handled
      assert result.private.update_character.room_id == @target
    end
  end

  # ---- helpers ----

  defp run_say(arg, conn) do
    case Say.run(conn, %{verb: "do_say", trailing: arg, room_id: conn.character.room_id}) do
      {:handled, conn2} -> conn2
      other -> other
    end
  end

  defp conn(room_id, opts \\ []) do
    character = %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      pid: self(),
      room_id: room_id,
      attributes: %{},
      meta: %PlayerMeta{temp: Keyword.get(opts, :temp, %{})}
    }

    %Conn{
      character: character,
      private: %Private{channel_changes: []},
      output: []
    }
  end
end
