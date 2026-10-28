defmodule Kantele.World.ForgingAnswer do
  @moduledoc """
  forge 品类选择（对应 LPC moye.c `do_answer`，L484–554）。

  在莫邪进程内执行（answer 命令经 room/forge_answer 转发到莫邪，命中活跃锻造会话时调用）。
  负责：
    1. 校验玩家选的类型：`arg ∈ session.types` 且类型表存在；
    2. 填 ctype/stype/unit/point/owner*/wscale/prop；
    3. 判定干将是否在场（按 id 在房间内查找）：
       - 在场 → 记会话 status=handoff，把材料转交干将（发 forge/handoff），房间广播；
       - 不在 → 退材料 + 退钱（发 forge/refund 给玩家），清会话，房间广播「我夫君呢」。

  玩家侧物品实例从背包移除/归还，由玩家进程收到 `forge/refund` 确认事件后完成
  （与 `forge/accept` 同款跨进程投递）。`forge/handoff` 由干将进程（S2）消费。
  """

  alias Kalevala.Event
  alias Kalevala.Character.Conn
  alias Kantele.Character.Records
  alias Kantele.World.Forging
  alias Kantele.World.Items
  alias Kantele.World.Room

  @doc """
  处理一次 `answer <类型>` 请求。

  - `event.data` 需含 `type` / `from_id` / `from_name` / `reply_to`（玩家 pid）。
  - `opts` 可带 `ganjiang_pid`（测试注入），非空时直接当作干将进程 pid，
    否则按 `npc.room_id` 在房间内查找 id 为 `"ganjiang"` 的 NPC。
  """
  def answer(conn, npc, event, opts \\ []) do
    data = event.data
    from_id = Map.get(data, :from_id) || Map.get(data, "from_id")
    type = Map.get(data, :type) || Map.get(data, "type")
    from_name = Map.get(data, :from_name) || Map.get(data, "from_name")
    reply_to = Map.get(data, :reply_to) || Map.get(data, "reply_to")

    session = Forging.get(from_id)

    cond do
      is_nil(session) or session.status != "answer_type" ->
        conn

      true ->
        do_answer(conn, npc, session, type, from_id, from_name, reply_to, opts)
    end
  end

  defp do_answer(conn, npc, session, type, from_id, from_name, reply_to, opts) do
    entry = Forging.type_entry(type)
    valid = not is_nil(entry) and type in session.types

    if not valid do
      room_say(conn, npc,
        "#{npc.name}看了看#{from_name}，有一搭没一搭的“嗯”了一声。\n")
    else
      material = Items.get!(session.material_item_id)
      point = div((material.meta.power_point || 0) * entry.point, 100)

      new_session =
        session
        |> Map.merge(%{
          status: "handoff",
          ctype: type,
          stype: entry.stype,
          unit: entry.unit,
          point: point,
          owner_id: session.owner_id,
          owner_name: session.owner_name,
          wscale: entry.weight,
          prop: entry.prop
        })

      ganjiang = find_ganjiang(npc, opts)

      if is_nil(ganjiang) do
        refund(conn, npc, session, reply_to)
      else
        handoff(conn, npc, session, new_session, material, ganjiang, from_name, type)
      end
    end
  end

  defp find_ganjiang(npc, opts) do
    case Keyword.get(opts, :ganjiang_pid) do
      pid when is_pid(pid) ->
        %{pid: pid, id: "ganjiang", name: "干将"}

      _ ->
        Enum.find(Room.npc_characters_by_id(npc.room_id) || [], &(&1.id == "ganjiang"))
    end
  end

  # 干将不在：退材料（从莫邪背包移出）+ 退钱（取自会话里的钱币实例），清会话
  defp refund(conn, npc, session, reply_to) do
    material_instance = Enum.find(npc.inventory, &(&1.id == session.material_instance_id))
    money_instance = Map.get(session, :money_instance)

    new_inventory = Enum.reject(npc.inventory, &(&1.id == session.material_instance_id))
    new_npc = %{npc | inventory: new_inventory}
    Records.save(new_npc)
    Forging.delete(session.owner_id)

    room_say(conn, npc,
      "#{npc.name}看了看四周，不禁一呆，说道：我夫君呢？没他在就没办法做了……你改天再来吧。\n")

    send(reply_to, %Event{
      from_pid: self(),
      topic: "forge/refund",
      data: %{material_instance: material_instance, money_instance: money_instance}
    })

    Conn.put_character(conn, new_npc)
  end

  # 干将在：材料转交干将，记 handoff 会话，房间广播「就打造 X 吧 / 把材料交给干将」
  defp handoff(conn, npc, session, new_session, material, ganjiang, from_name, type) do
    material_instance = Enum.find(npc.inventory, &(&1.id == session.material_instance_id))
    new_inventory = Enum.reject(npc.inventory, &(&1.id == session.material_instance_id))
    new_npc = %{npc | inventory: new_inventory}
    Records.save(new_npc)
    Forging.put(session.owner_id, new_session)

    room_say(conn, npc,
      "#{npc.name}对#{from_name}道：就打造「#{type}」吧！\n" <>
        "#{npc.name}点了点头，把#{material.name}交给了#{ganjiang.name}。\n")

    send(ganjiang.pid, %Event{
      from_pid: self(),
      topic: "forge/handoff",
      data: %{material_instance: material_instance, session: new_session, from_id: session.owner_id}
    })

    Conn.put_character(conn, new_npc)
  end

  defp room_say(conn, npc, text) do
    Room.tell_room(%{id: npc.room_id}, text)
    conn
  end
end
