defmodule Kantele.World.NpcInit do
  @moduledoc """
  逐 NPC 的 `init()` 反应派发（LPC `kungfu/class/ultra/*.c` 与
  `kungfu/class/xingxiu/ding.c:122-136` 的 `init()`）。

  运行时由 `Kantele.Character.Events.MoveEvent.notice/2` 在玩家进屋时调用：
  房间内每个 NPC 都会收到 LPC 的 `init()`。

  ## 大宗师（ultra）

  1. 无条件 `me->delete_temp("want_opinion")`：清掉玩家此前请求评价留下的意图
     （ex 侧为全部 `want_opinion/<key>` 键），经 `ultra/init` 事件投到玩家进程；
  2. `if (ultrap(me))` 时按各自逐字文案 `message_vision(...)`：
     独孤求败/黄裳微笑点头、霍山皱眉冷哼、葵花太监扫一眼冷笑。

  `ultrap/1` 在 LPC 是 `query("opinion/ultra")`（`adm/single/simul_efun/user.c:8`），
  不是 exp 阈值，因此这里读 `meta.env["opinion/ultra"]`，与
  `Kantele.NPC.Ultra.check_ultra/2` 写入的键一致。

  ## 丁春秋持鼎追杀（#816）

  LPC `ding.c:122-130`：`living(this_object()) && present("shenmu wangding", me)`
  时 `say` + `kill_ob(me)` 并 `return`（不落 `flatter`）；否则才
  `add_action("do_flatter", "flatter")`。ex 的 `flatter` 动词是静态注册，
  持鼎时由 `Kantele.World.NpcActions.XingxiuFlatter` 自己按同一条件拒绝，
  这里的 `init` 负责台词与双向 `combat/start`。

  文案取自 NPC 的 `meta.ultra.msgs["init"]`（UCL 原样存放，无硬编码）；
  返回 `{:vision, text}` 交给 `MoveEvent` 广播，`:skip` 表示无额外反应。
  """

  alias Kalevala.Event
  alias Kantele.Character.BeastTaming
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  @ding_names ["丁春秋", "xingxiu_ding", "ding chunqiu", "ding"]
  @ding_kill_msg "丁春秋说道：好家伙，原来你偷了我的神木王鼎！受死吧！\n"

  @doc "玩家进屋时触发 NPC 的 init()；返回 `{:vision, 文案}` 或 `:skip`。"
  def init(npc, player) do
    cond do
      ding_swmuding_kill?(npc, player) ->
        trigger_ding_kill(npc, player)
        :skip

      liu_zhengfeng_init?(npc, player) ->
        trigger_liu_zhengfeng_init(npc, player)

      true ->
        case ultra_init(npc, player) do
          text when is_binary(text) and text != "" -> {:vision, text}
          _ -> :skip
        end
    end
  end

  # ---- #816 丁春秋 init 持鼎追杀 ----

  defp ding_swmuding_kill?(npc, player) do
    is_map(npc) and is_map(player) and BeastTaming.living?(npc) and
      ding_chunqiu?(npc) and
      (RoomHelpers.carries?(player, "shenmu wangding") or
         RoomHelpers.carries?(player, "swmuding"))
  end

  defp ding_chunqiu?(%{name: name}) when is_binary(name), do: name in @ding_names

  defp ding_chunqiu?(%{meta: %{aliases: aliases}}) when is_list(aliases) do
    Enum.any?(aliases, &(&1 in @ding_names))
  end

  defp ding_chunqiu?(_), do: false

  defp trigger_ding_kill(npc, player) do
    if room_id = npc.room_id do
      Room.tell_room(%Room{id: room_id}, @ding_kill_msg)
    end

    ref = fn character ->
      %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
    end

    combat_event = fn enemy, initiator ->
      %Event{
        from_pid: self(),
        topic: "combat/start",
        data: %{enemy: ref.(enemy), initiator_id: initiator.id, type: "kill"}
      }
    end

    # LPC `kill_ob(me)`：双方各自把对方挂进 combat.enemies。
    if is_pid(npc.pid), do: send(npc.pid, combat_event.(player, npc))
    if is_pid(player.pid), do: send(player.pid, combat_event.(npc, npc))

    :ok
  rescue
    _ -> :ok
  end

  # ---- 大宗师 init ----

  # 四位大宗师共用的 init() 骨架：先清意图（无条件），再按 ultrap 决定是否显文案。
  defp ultra_init(%{meta: %{ultra: cfg}} = _npc, player) when is_map(cfg) do
    notify_clear_intent(player)

    if ultrap?(player) do
      Map.get(Map.get(cfg, :msgs) || %{}, "init")
    else
      nil
    end
  end

  defp ultra_init(_npc, _player), do: nil

  # LPC `ultrap(ob) = ob->query("opinion/ultra")`（非 exp 门槛）。
  defp ultrap?(%{meta: %{env: env}}) when is_map(env) do
    truthy?(Map.get(env, "opinion/ultra") || Map.get(env, :"opinion/ultra"))
  end

  defp ultrap?(_), do: false

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?("0"), do: false
  defp truthy?("false"), do: false
  defp truthy?(_), do: true

  # NPC 进程不能直接改玩家 meta；发事件给玩家进程自己清。
  defp notify_clear_intent(%{pid: pid}) when is_pid(pid) do
    send(pid, %Event{
      from_pid: self(),
      topic: "ultra/init",
      data: %{clear_want_opinion: true}
    })
  end

  defp notify_clear_intent(_player), do: :ok

  # ---- #867 刘正风 init()：在 startroom 吹笑傲江湖，不在 startroom 则叹息 ----

  # LPC liu.c:176-195：interactive(ob) && !is_fighting() 时，
  # environment(me) == startroom → command("play xiaoao-jianghu")
  # 否则 → say(name + "深深地叹了口气。")
  defp liu_zhengfeng_init?(npc, player) do
    is_map(npc) and is_map(player) and liu_zhengfeng?(npc) and not fighting?(npc)
  end

  defp liu_zhengfeng?(%{name: name}) when is_binary(name), do: name == "刘正风"
  defp liu_zhengfeng?(_), do: false

  defp fighting?(%{meta: %Kantele.Character.NonPlayerMeta{combat: %Kantele.Character.Combat{enemies: enemies}}}) when is_list(enemies),
    do: not Enum.empty?(enemies)
  defp fighting?(_), do: false

  defp trigger_liu_zhengfeng_init(npc, player) do
    if npc.meta.startroom && npc.meta.startroom == npc.room_id do
      # 在 startroom：command("play xiaoao-jianghu")
      {:vision, "刘正风抚琴一曲，《笑傲江湖》的琴声缓缓流出。\n"}
    else
      # 不在 startroom：say(name + "深深地叹了口气。")
      {:vision, "刘正风深深地叹了口气。\n"}
    end
  rescue
    _ -> :skip
  end
end
