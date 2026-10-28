defmodule Kantele.Character.GanjiangEvent do
  @moduledoc """
  干将锻造链（对应 LPC `ganjiang.c` `accept_object`/`start_work`/`prepare_make`/`work_step_1..6`）。

  在干将进程内执行（NonPlayerEvents，命中 `forge/handoff`；由莫邪在
  `Kantele.Character.ForgingAnswer.handoff`（S1c）直接投递）。

  ## 时序（LPC 的 `call_out` 链，本仓用 `ForgingTimeout.schedule/4` 复刻）

  | 阶段 | 相对上一跳 | 内容 | 会话变化 |
  |---|---|---|---|
  | `start_work` → `prepare_make` | 1s | 开炉、抛料入炉 | `status="waiting"` |
  | `work_step_1` | 5s | 炉火转绿 + 请「注内力」 | `can_help=true`（玩家在场时） |
  | `work_step_2` | 6s | 炉火转红 | `can_help=false` ← **注内力窗口只有这 6 秒** |
  | `work_step_3` | 3s | 锤打成型 | — |
  | `work_step_4` | 5s | 淬火 | — |
  | `work_step_5` | 3s | 抽出成品 | — |
  | `work_step_6` | 2s | 请玩家起名 + 规则 | `status="inputing"`，`waited=4`，排 240s 等待 |

  早先这一整条链被折叠成 `handoff` 里的即时广播，`can_help` 一置上就再没清过，
  于是「注内力」在起名阶段随时可用 —— 与 LPC 的 6 秒窗口不符。现在按原时序分步。
  """

  use Kalevala.Character.Event

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.Records
  alias Kantele.World.Forging
  alias Kantele.World.ForgingTimeout
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @prepare_delay 1
  @step_1_delay 5
  @step_2_delay 6
  @step_3_delay 3
  @step_4_delay 5
  @step_5_delay 3
  @step_6_delay 2

  # 七段 vision（`prepare_make` + `work_step_1..6`）。
  #
  # `$N` 留给 `Helpers.broadcast_vision/4` 归一成 `{npc}`（由 `VisionView` 按
  # 接收者渲染成「你」/干将名）；材料名、类型、单位是**与接收者无关**的字面量，
  # 发布前直接替换。
  #
  # 早先这里用的是 `Room.message_vision/3`，而该函数发的是 `{:vision_message, ...}`
  # —— 角色进程只处理 `{:room_message, ...}`（`Kalevala.Character.Foreman`），
  # 所以这些文案**一条都没送到玩家**。现改走房间频道的 vision 事件。
  @visions [
    ~s($N说道：好，开炉锻炼！\n$N接过莫邪手中的$n，随手把它抛入炉内，霎时间，那$n已被火炉中的熊熊烈焰吞没。\n$N凝视着炉火，喃喃说道：天地之精华为其血脉，日月之光辉是其灵气……\n),
    ~s(炉火渐渐的转成了绿色，火苗不断跳跃，你觉得屋内十分燥热，可是干将莫邪若无其事。\n$N对$n说道：如果你想炼得更好，需要注入自己的精气血脉，如是你有此意，请「注内力」助我一臂之力。\n),
    ~s(炉火淡淡的暗了下来，呈现出一片红色……\n),
    ~s($N左手持蛟龙剪，一扬手已经取出了$n，右手持金刚锤聚精会神地用力锤打。\n渐渐的，$n在干将手下成了$ctype的形状。\n),
    ~s($N锤打完毕，大喝一声，将$ctype抛入水池，只听丝丝作响，从水池腾起一股雾气，弥漫四周。\n),
    ~s($N缓缓的从水池抽出了炼好的$ctype，看了看，满意地说，很好，很好。\n),
    ~s(一$unit好$ctype不能没有名字，你给它起个名字吧！\n)
  ]

  # LPC `tell_rules` 的 @RULES（tell_object，只发给玩家）
  @rules """
  干将在你耳边悄声说道：
  名字需要你来定，其它信息系统有缺省的描述，当然也可以由你自己为它自定描述。
  当然了，最好不用让别人误会的词语字句噢。具体的方法如下。
      命名: name 中文名字 英文代号。   (必须有)
      描述: desc 武器的描述文字。      (可  选)
      装备: wieldmsg   装备时的描述。  (可  选)
      收起: unwieldmsg 收起时的描述。  (可  选)
  描述时分行请用\\n，除了英文代号以外所有的文字都可以用颜色。
  如果你觉得可以了，就请告诉我(finish)，要是没看清楚，可以再问我一次。

  """

  def handoff(conn, %{data: %{material_instance: material_instance, session: session}} = _event) do
    npc = conn.character

    # 1. 材料计入干将背包并落盘
    npc = %{npc | inventory: [material_instance | npc.inventory]}
    Records.save(npc)

    # 2. 会话进入 waiting（LPC `start_work`：`me->set_temp("item/status","waiting")`）
    session =
      session
      |> Map.merge(%{
        status: "waiting",
        can_help: false,
        making_instance_id: material_instance.id,
        waited: ForgingTimeout.max_waited()
      })

    Forging.put(session.owner_id, session)

    # 3. 1 秒后开炉（LPC `start_work` → `call_out("prepare_make", 1)`）
    ForgingTimeout.schedule(session.owner_id, "forge/step", @prepare_delay, %{step: "prepare"})

    Conn.put_character(conn, npc)
  end

  @doc "`forge/step`：锻造链的每一跳（`prepare` 与 1..6）。"
  def step(conn, %{data: %{owner_id: owner_id, token: token, step: step}}) do
    with true <- ForgingTimeout.valid?(owner_id, token),
         %{} = session <- Forging.get(owner_id) do
      do_step(conn, session, step)
    else
      _ -> conn
    end
  end

  defp do_step(conn, session, "prepare") do
    conn = broadcast(conn, session, 0)
    ForgingTimeout.schedule(session.owner_id, "forge/step", @step_1_delay, %{step: 1})
    conn
  end

  # work_step_1：玩家在场才置 can_help（LPC `if (objectp(me) && environment(me) == environment())`）
  defp do_step(conn, session, 1) do
    conn = broadcast(conn, session, 1)

    if in_room?(conn, session.owner_id) do
      Forging.put(session.owner_id, Map.put(session, :can_help, true))
    end

    ForgingTimeout.schedule(session.owner_id, "forge/step", @step_2_delay, %{step: 2})
    conn
  end

  # work_step_2：关闭注内力窗口
  defp do_step(conn, session, 2) do
    conn = broadcast(conn, session, 2)
    Forging.put(session.owner_id, Map.put(session, :can_help, false))
    ForgingTimeout.schedule(session.owner_id, "forge/step", @step_3_delay, %{step: 3})
    conn
  end

  defp do_step(conn, session, 3) do
    conn = broadcast(conn, session, 3)
    ForgingTimeout.schedule(session.owner_id, "forge/step", @step_4_delay, %{step: 4})
    conn
  end

  defp do_step(conn, session, 4) do
    conn = broadcast(conn, session, 4)
    ForgingTimeout.schedule(session.owner_id, "forge/step", @step_5_delay, %{step: 5})
    conn
  end

  defp do_step(conn, session, 5) do
    conn = broadcast(conn, session, 5)
    ForgingTimeout.schedule(session.owner_id, "forge/step", @step_6_delay, %{step: 6})
    conn
  end

  # work_step_6：确认莫邪与玩家都在场 → 进入起名阶段，排 240s 等待
  defp do_step(conn, session, 6) do
    npc = conn.character

    cond do
      not in_room?(conn, Forging.moye_id()) ->
        say(npc,
          "#{npc.name}看了看四周，说道：咦，莫邪呢？算了算了，不做了，去吧！\n" <>
            "#{npc.name}把炼好的道具抛进火炉，就此不见。\n"
        )

        abort(conn, session, npc)

      not in_room?(conn, session.owner_id) ->
        say(npc,
          "#{npc.name}叹了口气，说道：客人为何这就去了！？罢了罢了，不做了，去吧！\n" <>
            "#{npc.name}把炼好的道具抛进火炉，就此不见。\n"
        )

        abort(conn, session, npc)

      true ->
        session =
          session
          |> Map.merge(%{status: "inputing", can_help: false, waited: ForgingTimeout.max_waited()})

        Forging.put(session.owner_id, session)

        conn
        |> broadcast(session, 6)
        |> notify_rules(session)
        |> tap(fn _ -> schedule_waiting(session) end)
    end
  end

  # ---- helpers ----

  defp schedule_waiting(session) do
    ForgingTimeout.schedule(session.owner_id, "forge/waiting", ForgingTimeout.waiting_first())
  end

  defp broadcast(conn, session, index) do
    npc = conn.character

    text =
      @visions
      |> Enum.at(index)
      |> substitute(
        material_name(session),
        Map.get(session, :ctype) || "武器",
        Map.get(session, :unit) || "件"
      )

    Helpers.broadcast_vision(conn, npc.room_id, text)
  end

  defp material_name(session) do
    case Items.get(Map.get(session, :material_item_id)) do
      {:ok, item} -> item.name
      _ -> Map.get(session, :material_name) || "材料"
    end
  end

  defp substitute(template, material_name, ctype, unit) do
    template
    |> String.replace("$n", material_name)
    |> String.replace("$ctype", ctype)
    |> String.replace("$unit", unit)
  end

  defp notify_rules(conn, session) do
    case Map.get(session, :player_pid) do
      pid when is_pid(pid) ->
        send(pid, %Event{
          from_pid: self(),
          topic: "forge/notice",
          data: %{text: @rules}
        })

        conn

      _ ->
        conn
    end
  end

  # 中止：成品销毁（LPC `destruct(ob)` + `delete_temp("item")`）
  defp abort(conn, session, npc) do
    instance_id = Map.get(session, :making_instance_id)
    npc = %{npc | inventory: Enum.reject(npc.inventory, &(&1.id == instance_id))}
    Records.save(npc)
    Forging.delete(session.owner_id)

    Conn.put_character(conn, npc)
  end

  defp in_room?(conn, id) do
    Enum.any?(Room.characters_for_conn(conn), &(Map.get(&1, :id) == id))
  end

  defp say(npc, text), do: Room.tell_room(%{id: npc.room_id}, text)
end
