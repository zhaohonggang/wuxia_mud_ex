defmodule Kantele.Character.ForgingTimeoutEvent do
  @moduledoc """
  锻造超时的两个事件处理器（定时原语在 `Kantele.World.ForgingTimeout`）。

  - `forge/quote_timeout` —— 莫邪进程，对应 LPC `moye.c time_out`（30 秒未付款退料）
  - `forge/waiting` —— 干将进程，对应 LPC `ganjiang.c waiting`（起名阶段超时）

  两者都由 `Process.send_after/3` 投回**排程的那个 NPC 进程**，因此 `conn.character`
  就是莫邪 / 干将本人。
  """

  use Kalevala.Character.Event

  require Logger

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.Records
  alias Kantele.World.Forging
  alias Kantele.World.ForgingTimeout
  alias Kantele.World.Room

  # ---- moye.c time_out：报价超时退款 ----

  @doc """
  LPC `time_out(me, ob)`：30 秒没交钱就把材料（以及已付的钱）退回去；
  玩家已经离开就把东西扔在地上。
  """
  def quote_timeout(conn, %{data: %{owner_id: owner_id, token: token}}) do
    with true <- ForgingTimeout.valid?(owner_id, token),
         %{} = session <- Forging.get(owner_id) do
      do_quote_timeout(conn, session)
    else
      _ -> conn
    end
  end

  defp do_quote_timeout(conn, session) do
    npc = conn.character
    owner_id = session.owner_id
    instance_id = Map.get(session, :material_instance_id)
    material_instance = Enum.find(npc.inventory, &(&1.id == instance_id))
    money_instance = Map.get(session, :money_instance)

    npc = %{npc | inventory: Enum.reject(npc.inventory, &(&1.id == instance_id))}
    Records.save(npc)
    Forging.delete(owner_id)

    conn = Conn.put_character(conn, npc)

    case player_in_room(conn, owner_id) do
      %{} = player ->
        say(npc, "#{npc.name}说道：你慢慢犹豫吧，我可不能跟你耗着！想好再来吧！\n")
        deliver_refund(player.pid, material_instance, money_instance)
        conn

      nil ->
        say(npc, "#{npc.name}说道：奇怪，刚才那位客人呢？怎么这就走了？\n")
        # LPC `command("drop " + ...)`：玩家不在就把东西扔在地上
        drop_all(conn, [material_instance, money_instance])
    end
  end

  # ---- ganjiang.c waiting：起名阶段超时 ----

  @doc """
  LPC `waiting(me, ob, moye)` 的逐分支移植：

    1. 玩家对象没了 → 「怎么这走了，算了算了，去吧！」+ 销毁成品
    2. `waited` 减到 0 → 销毁成品、**不退款**；玩家在场说「算了，不要就不要吧」，
       不在场说「恕不退款」
    3. 还有次数 → 不在场说「人怎么跑掉了？」，在场就催「快点，快点」，
       然后 300 秒后重排
  """
  def waiting(conn, %{data: %{owner_id: owner_id, token: token}}) do
    with true <- ForgingTimeout.valid?(owner_id, token),
         %{} = session <- Forging.get(owner_id) do
      do_waiting(conn, session)
    else
      _ -> conn
    end
  end

  defp do_waiting(conn, session) do
    npc = conn.character
    owner_id = session.owner_id
    in_room? = not is_nil(player_in_room(conn, owner_id))

    cond do
      not player_alive?(session) ->
        say(npc, "#{npc.name}叹了口气说道：怎么这走了，算了算了，去吧！\n")
        destroy_making(conn, session, npc)

      decrement_waited(session) <= 0 ->
        Logger.info("forging waiting timeout: #{owner_id} gave up, item destroyed")

        say(npc, timeout_line(npc, session, in_room?))
        destroy_making(conn, session, npc)

      true ->
        say(npc, nag_line(npc, session, in_room?))
        Forging.put(owner_id, Map.put(session, :waited, decrement_waited(session)))
        ForgingTimeout.schedule(owner_id, "forge/waiting", ForgingTimeout.waiting_next())
        conn
    end
  end

  # LPC 只在 `environment(me) == environment()` 时才对 `$n` 说话（否则只说给旁人听）
  defp timeout_line(npc, _session, true) do
    "#{npc.name}皱了皱眉头说道：这人怎么这么磨蹭，算了，不要就不要吧！\n"
  end

  defp timeout_line(npc, session, false) do
    "#{npc.name}皱了皱眉头对#{session.owner_name}说道：" <>
      "你这人怎么这么磨蹭，不要就算了，恕不退款！\n"
  end

  defp nag_line(npc, session, true) do
    "#{npc.name}催#{session.owner_name}道：快点，快点，别磨蹭，否则我可就不做了。\n"
  end

  defp nag_line(npc, _session, false) do
    "#{npc.name}疑惑地说道：人怎么跑掉了？算了，再等他一会吧。\n"
  end

  # LPC `add_temp("item/waited", -1)`
  defp decrement_waited(session) do
    Map.get(session, :waited, ForgingTimeout.max_waited()) - 1
  end

  # ---- 共用小工具 ----

  defp player_alive?(session) do
    case Map.get(session, :player_pid) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _ -> false
    end
  end

  defp player_in_room(conn, owner_id) do
    Enum.find(Room.characters_for_conn(conn), &(Map.get(&1, :id) == owner_id))
  end

  # 销毁半成品：从干将背包移除，会话清空（LPC `destruct(ob)` + `delete_temp("item")`）
  defp destroy_making(conn, session, npc) do
    instance_id = Map.get(session, :making_instance_id)
    npc = %{npc | inventory: Enum.reject(npc.inventory, &(&1.id == instance_id))}
    Records.save(npc)
    Forging.delete(session.owner_id)

    Conn.put_character(conn, npc)
  end

  defp deliver_refund(pid, material_instance, money_instance) do
    send(pid, %Event{
      from_pid: self(),
      topic: "forge/refund",
      data: %{
        material_instance: material_instance,
        money_instance: money_instance,
        message: "莫邪把材料与定金交还给了你。\n"
      }
    })
  end

  defp drop_all(conn, instances) do
    Enum.reduce(instances, conn, fn
      nil, acc -> acc
      instance, acc -> Conn.request_item_drop(acc, instance)
    end)
  end

  defp say(npc, text), do: Room.tell_room(%{id: npc.room_id}, text)
end
