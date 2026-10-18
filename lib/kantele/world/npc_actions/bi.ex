defmodule Kantele.World.NpcActions.Bi do
  @moduledoc """
  NPC 私有动词 `bi` / `get`（P5-1c，full `bi` 屠龙刀闯关）。

  移植 `d/tulong/tulong/npc/{chang,guo,mai,yuan}.c` 的会场四关：玩家在屠龙刀
  大铁鼎（`ding`）前对四名 NPC 依次叫阵，比运气/比毒，赢者得刀。

  ## 进程边界（关键）

  LPC 里 `begin()`/`do_bi()` 跑在同一进程，`this_object()`=NPC、`me`=玩家。本
  引擎里玩家命令由**玩家进程**执行、NPC 自身状态（`set("anti")`、自落
  `condition`）只能由**NPC 进程**改，故按需拆分：

  - 玩家侧 `run/2`（玩家进程）：判 `present()` 关卡顺序 → 广播对玩家可见的
    文案（`$N`=玩家，旁观者见玩家名、玩家见「你」）→ 给玩家落
    `bi` 临时标记与初始 `condition` → 给目标 NPC 发 `bi/begin` 事件。
  - NPC 侧 `on_begin/2`（NPC 进程，`NonPlayerEvents` 路由）：记 `anti`、给
    自己落更重的 `condition`、`call_out` 后手、以及过三拳的三连击。
  - 倒下：条件把 NPC 气/精拖到 0 → `condition/down` → `DownHandlers` →
    `on_mai_down/2` / `on_yuan_down/2`（NPC 进程）→ 通知玩家 `bi/result`
    （带上要广播的文案）+ `Down.mark_dead/3`。
  - 玩家侧 `client_result/2`（玩家进程）：落 `win_*`、清 `bi`、清玩家
    `condition`、把死亡文案按 `$N`=玩家广播。

  双人 `message_vision`（`$N`/`$n`）统一改写为「行动者进程 + `$N`」，NPC 名
  字面内插，避免 `broadcast_vision/4` 只认 `$N` 的限制（见 `helpers.ex`）。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [get_session: 2, put_session: 3, put_character: 2]

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.World.NpcActions.CallOut
  alias Kantele.World.NpcActions.Down
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.NpcActions.NpcAttack
  alias Kantele.World.Room

  @bi "bi"

  # ---- 玩家侧入口 ----

  @impl true
  def run(conn, %{verb: verb, room_id: room_id} = params) do
    case verb do
      "bi" -> do_bi(conn, room_id)
      "get" -> do_get(conn, room_id, Map.get(params, :trailing, ""))
      _ -> :not_handled
    end
  end

  # 按 LPC 关卡顺序（常金鹏最外 → 过三拳最内）逐个 NPC 试。
  # 每个 NPC 自带「下一个还在场就 return 0」的守卫，故只要按顺序试，命中者唯一。
  defp do_bi(conn, room_id) do
    attempt(room_id, :bi, conn)
  end

  defp do_get(conn, room_id, trailing) do
    case parse_from(trailing) do
      {_what, "ding"} -> attempt(room_id, :get, conn)
      _ -> :not_handled
    end
  end

  defp attempt(room_id, kind, conn) do
    Enum.reduce_while(guarded_order(), :not_handled, fn alias_, _acc ->
      case {find_alias(room_id, alias_), dispatch(kind, alias_, room_id, conn)} do
        {nil, _} -> {:cont, :not_handled}
        {_npc, :skip} -> {:cont, :not_handled}
        {_npc, conn} -> {:halt, conn}
      end
    end)
  end

  defp guarded_order, do: ["chang jinpeng", "yuan guangbo", "mai jing", "guo sanquan"]

  defp dispatch(:bi, alias_, room_id, conn), do: bi_for(alias_, room_id, conn)
  defp dispatch(:get, alias_, room_id, conn), do: get_for(alias_, room_id, conn)

  # ---- bi：四关 ----

  # 常金鹏：无守卫，直接开打。
  defp bi_for("chang jinpeng", room_id, conn) do
    npc = find_alias(room_id, "chang jinpeng")

    conn =
      Helpers.broadcast(conn, room_id, "#{npc.name}对$N大喝一声：比什么比，去死吧！\n")

    NpcAttack.kill_ob(npc, room_snapshot(room_id, conn.character.id))
    conn
  end

  # 元广波：常金鹏在场则让关 → 毒盐。玩家躲 `duyan`、元吃重剂量。
  defp bi_for("yuan guangbo", room_id, conn) do
    npc = find_alias(room_id, "yuan guangbo")

    if find_alias(room_id, "chang jinpeng") do
      :skip
    else
      conn =
        conn
        |> Helpers.broadcast(room_id, "#{npc.name}咧开嘴一笑。\n")
        |> Helpers.broadcast(room_id, "#{npc.name}说道：我海沙帮的绝技，乃是使用毒盐害人，如今你我各吃一碗，如何？\n")
        |> Helpers.broadcast(room_id, "#{npc.name}叫手下装了两大碗毒盐，#{npc.name}和$N各吃一碗。\n")
        |> Helpers.put_temp(@bi, 1)
        |> ConditionEvent.grant("duyan", %{"duration" => :rand.uniform(4)})

      send_begin(npc, conn.character, :yuan)
      conn
    end
  end

  # 麦鲸：元广波在场则让关 → 湿泥堵嘴。玩家躲 `nishui`、麦吃重剂量。
  defp bi_for("mai jing", room_id, conn) do
    npc = find_alias(room_id, "mai jing")

    if find_alias(room_id, "yuan guangbo") do
      :skip
    else
      conn =
        conn
        |> Helpers.broadcast(room_id, "#{npc.name}点了点头。\n")
        |> Helpers.broadcast(room_id, "#{npc.name}说道：我巨鲸帮的绝技，乃是使用水上功夫。\n")
        |> Helpers.broadcast(room_id, "#{npc.name}说道：如今你我各用湿泥糊嘴，比试一下水上功夫，如何？\n")
        |> Helpers.broadcast(room_id, "$N和#{npc.name}各取湿泥，糊上口鼻。\n")
        |> Helpers.put_temp(@bi, 1)
        |> ConditionEvent.grant("nishui", %{"duration" => :rand.uniform(4)})

      send_begin(npc, conn.character, :mai)
      conn
    end
  end

  # 过三拳：麦鲸在场则让关 → 硬桥硬马三拳。
  defp bi_for("guo sanquan", room_id, conn) do
    npc = find_alias(room_id, "guo sanquan")

    if find_alias(room_id, "mai jing") do
      :skip
    else
      conn = Helpers.put_temp(conn, @bi, 1)
      send_begin(npc, conn.character, :guo)
      conn
    end
  end

  # ---- get <x> from ding ----

  defp get_for("chang jinpeng", room_id, conn) do
    npc = find_alias(room_id, "chang jinpeng")

    conn =
      conn
      |> Helpers.broadcast(room_id, "#{npc.name}对$N大喝一声：大胆！竟敢打宝刀的主意！\n")
      |> Helpers.broadcast(room_id, "#{npc.name}对$N喝道：去死吧。\n")

    NpcAttack.kill_ob(npc, room_snapshot(room_id, conn.character.id))
    conn
  end

  defp get_for("yuan guangbo", room_id, conn) do
    if find_alias(room_id, "chang jinpeng") do
      :skip
    else
      npc = find_alias(room_id, "yuan guangbo")

      conn
      |> Helpers.broadcast(room_id, "#{npc.name}喝道：无耻小贼，给我住手！你凭什么得此宝刀？\n")
      |> Helpers.broadcast(room_id, "#{npc.name}冷冷地说道：要得此刀，先比(bi)赢了我再说！\n")
      |> Helpers.delete_temp(@bi)
    end
  end

  defp get_for("mai jing", room_id, conn) do
    if find_alias(room_id, "yuan guangbo") do
      :skip
    else
      npc = find_alias(room_id, "mai jing")

      conn
      |> Helpers.broadcast(room_id, "#{npc.name}正色道：这位英雄请了！\n")
      |> Helpers.broadcast(room_id, "#{npc.name}说道：屠龙宝刀乃不世之宝，要得此刀，需过(bi)了我这关！\n")
      |> Helpers.delete_temp(@bi)
    end
  end

  defp get_for("guo sanquan", room_id, conn) do
    if find_alias(room_id, "mai jing") do
      :skip
    else
      npc = find_alias(room_id, "guo sanquan")

      conn
      |> Helpers.broadcast(room_id, "#{npc.name}哼了一声。\n")
      |> Helpers.broadcast(room_id, "#{npc.name}说道：要想得到宝刀，先过我三拳！\n")
      |> Helpers.delete_temp(@bi)
    end
  end

  # ---- NPC 侧：begin 事件 ----

  @doc "NPC 自身收到 `bi/begin`：记 anti、落自重 condition、call_out 后手 / 三连击"
  def on_begin(conn, %{data: %{kind: kind, player_id: player_id}}) do
    case kind do
      :mai -> npc_begin(conn, player_id, "nishui", {:call_out, :guo})
      :yuan -> npc_begin(conn, player_id, "duyan", nil)
      :guo -> guo_begin(conn, player_id)
      _ -> conn
    end
  end

  defp npc_begin(conn, player_id, condition, action) do
    conn =
      conn
      |> put_session("anti", player_id)
      |> ConditionEvent.grant(condition, %{"duration" => :rand.uniform(10) + 9})

    case action do
      {:call_out, fun} ->
        CallOut.schedule(conn.character, __MODULE__, fun, 6, [player_id])
        conn

      _ ->
        conn
    end
  end

  # 麦鲸 6 秒后手：过三拳若在场则接力开场（LPC `guo(me)`）。
  @doc "call_out 兑现：叫过三拳接着上（NPC 进程）"
  def guo(conn, player_id) do
    case find_alias(conn.character.room_id, "guo sanquan") do
      nil -> conn
      guo ->
        send_begin(guo, %{id: player_id}, :guo)
        conn
    end
  end

  # 过三拳三连击：文案 + do_attack ×3，第三拳前 self-apply/attack 250。
  defp guo_begin(conn, player_id) do
    npc = conn.character
    room_id = npc.room_id
    player = room_snapshot(room_id, player_id)

    conn =
      conn
      |> Helpers.broadcast(room_id, "#{npc.name}抱拳道：阁下对不住了，今日我如不趁人之危，定会死于阁下之手！\n")
      |> Helpers.broadcast(room_id, "#{npc.name}说道：我神拳门绝技，乃是使用手上功夫，先吃我三拳再说。\n")
      |> Helpers.broadcast(room_id, "\n#{npc.name}喝道：小心了！我这第一拳乃“催筋断骨”！\n")

    NpcAttack.strike(npc, player)

    conn =
      Helpers.broadcast(conn, room_id, "\n#{npc.name}喝道：好！看我第二拳“崩山裂石”！\n")

    NpcAttack.strike(npc, player)

    conn =
      conn
      |> Helpers.broadcast(room_id, "\n#{npc.name}喝道：第三拳来了！这式叫做“横扫千军，直摧万马”！\n")
      |> put_session("anti", player_id)
      |> boost_attack()

    NpcAttack.strike(conn.character, player)

    if strong?(player) do
      on_guo_down(conn, %{cause: :ning})
    else
      conn
    end
  end

  # 过三拳自身倒下（被 max_neili>2000 的玩家「反震」）：LPC `die()`。
  defp on_guo_down(conn, _opts) do
    npc = conn.character
    player_id = get_session(conn, "anti")

    notify(
      conn,
      player_id,
      "win_guo",
      nil,
      [
        "\n\n#{npc.name}一拳端端正正的击中了$N的小腹。\n",
        "人身的小腹本来极是柔软，但#{npc.name}着拳时如中铁石，刚知不妙，已狂喷鲜血。\n"
      ]
    )

    Down.mark_dead(conn, npc, player_id)
  end

  # ---- 条件致倒：麦鲸 / 元广波 ----

  @doc "麦鲸倒下（NPC 进程）：通知玩家 + 落死"
  def on_mai_down(conn, _opts) do
    npc = conn.character
    player_id = get_session(conn, "anti")
    notify(
      conn,
      player_id,
      "win_mai",
      "nishui",
      ["\n\n#{npc.name}挣扎了两下，一口气没接上，倒在地上一动不动了。\n"]
    )

    Down.mark_dead(conn, npc, player_id)
  end

  @doc "元广波倒下（NPC 进程）：通知玩家 + 落死"
  def on_yuan_down(conn, _opts) do
    npc = conn.character
    player_id = get_session(conn, "anti")
    notify(
      conn,
      player_id,
      "win_yuan",
      nil,
      [
        "#{npc.name}说道：佩服，佩服......\n",
        "\n#{npc.name}嘶哑着嗓子干嚎了两声，双眼翻白，跌倒在地，口中吐出一些白沫，就再也没动了。\n"
      ]
    )

    Down.mark_dead(conn, npc, player_id)
  end

  # ---- 玩家侧：结果事件 ----

  @doc """
  玩家收到 `bi/result`：落 `win_*`、清 `bi`、清玩家 condition，并按 `$N`=玩家
  广播赢局/死亡文案（死亡文案由 NPC 侧随事件下发，此处以玩家进程广播）。
  """
  def client_result(conn, event) do
    flag = Map.get(event.data, :flag)
    clear = Map.get(event.data, :clear)
    lines = Map.get(event.data, :lines, [])

    conn =
      if is_binary(flag) do
        Helpers.put_temp(conn, flag, 1)
      else
        conn
      end

    conn =
      case clear do
        name when is_binary(name) -> clear_condition(conn, name)
        _ -> conn
      end

    Enum.reduce(lines, conn, fn line, conn ->
      Helpers.broadcast(conn, conn.character.room_id, line)
    end)
  end

  defp clear_condition(conn, name) do
    conds = (get_session(conn, "conditions") || %{}) |> Map.delete(name)
    put_session(conn, "conditions", if(map_size(conds) == 0, do: nil, else: conds))
  end

  # ---- 通知玩家（含随行死亡文案） ----

  defp notify(conn, player_id, flag, clear, lines \\ []) do
    case room_snapshot(conn.character.room_id, player_id) do
      %{pid: pid} when is_pid(pid) ->
        send(pid, %Event{
          from_pid: self(),
          topic: "bi/result",
          data: %{flag: flag, clear: clear, lines: lines}
        })

        conn

      _ ->
        conn
    end
  end

  # ---- 工具 ----

  defp send_begin(npc, player, kind) do
    case Map.get(npc, :pid) do
      pid when is_pid(pid) ->
        send(pid, %Event{
          from_pid: self(),
          topic: "bi/begin",
          data: %{kind: kind, player_id: player.id}
        })

        :ok

      _ ->
        {:error, :no_process}
    end
  end

  defp boost_attack(conn) do
    character = conn.character
    combat = Combat.apply_temp(character.meta.combat, %{attack: 250, damage: 250, unarmed_damage: 250})
    put_character(conn, put_in(character, [:meta, :combat], combat))
  end

  defp strong?(%{meta: %{vitals: %{max_neili: n}}}), do: is_integer(n) and n > 2000
  defp strong?(_player), do: false

  defp parse_from(trailing) when is_binary(trailing) do
    case Regex.run(~r/^\s*(.+?)\s+from\s+(\S+)\s*$/u, trailing) do
      [_, what, where] -> {String.trim(what), where}
      _ -> nil
    end
  end

  defp parse_from(_), do: nil

  defp room_chars(room_id), do: Room.npc_characters_by_id(room_id) |> List.wrap()
  defp find_alias(room_id, alias_), do: Enum.find(room_chars(room_id), &alias?(&1, alias_))
  defp room_snapshot(room_id, id), do: Enum.find(room_chars(room_id), &(Map.get(&1, :id) == id))

  defp alias?(%{meta: %{aliases: aliases}}, alias_) when is_list(aliases), do: alias_ in aliases
  defp alias?(_character, _alias_), do: false
end
