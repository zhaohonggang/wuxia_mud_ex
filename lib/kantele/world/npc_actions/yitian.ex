defmodule Kantele.World.NpcActions.Yitian do
  @moduledoc """
  NPC 私有动词 `bi`——倚天屠龙记万安寺四关（P5-1c-4）。

  移植 `d/tulong/yitian/npc/{he,asan,aer,ada}.c` 的 `begin()`（阿大名
  `ada.c`，与 b 树副本同源；b/ 区无 UCL，不接线）：

  - 何太冲（`he taichong`，昆仑掌门）：无前置守卫，**必须装备剑类兵器**
    才肯比剑（LPC `weapon->query("skill_type") != "sword"` 拒绝）。
  - 阿三（`a san`）：需 `win_he` 标记（赢过何太冲），且**必须空手**。
  - 阿二（`a er`）：需 `win_asan` 标记，且**必须空手**。
  - 阿大（`a da`）：需 `win_aer` 标记，且**必须持兵器**；若屋内地上有
    倚天剑（`tulong:yitianjian`）则播倚天剑飞入手套 sequence。

  四名 NPC 同处 `tulong:was_lou4`（UCL `room_characters` 顺序
  ada/aer/asan/he），LPC 用「下一关在场就 `return 0`」+ 各关 `die()`
  往击杀者落 `win_*` 临时标记串链；击杀后 NPC 在 LPC 被 `destruct`
  永久移除。Kantele 侧 NPC 原地装死 60s 复活（`Down.mark_dead`），故：

  - 尝试顺序按链条 he → asan → aer → ada 逐关试，**跳过已倒下的 NPC**
    （`combat.dead`），与 LPC「destruct 后不在场」等价；
  - 关卡解锁凭击杀者自身的 `win_*` 临时标记（LPC 同款语义：temp 是
    永久记录，不会因尸体复活而收回）。

  ## 进程边界（与 `Bi` 同构）

  - 玩家侧 `run/2`（玩家进程）：链条尝试 → 守卫拒绝（`notify_fail`
    文案）/ 开打：广播 LPC 开场文案（`$N`=玩家）→ 落 `bi` 临时标记 →
    `NpcAttack.kill_ob` 互相开战 → 给 NPC 发 `yitian/begin`。
  - NPC 侧 `on_begin/2`（NPC 进程，`NonPlayerEvents` 路由）：记
    `anti`、按各关 LPC 出招意象出数击（`NpcAttack.strike`）、
    `CallOut` 安排 8 拍后的 `resolve/2`（对应 LPC 分出胜负）。
  - `resolve/2`：NPC 自身敌人列表里没有该玩家（玩家已死/逃/下线）
    则跳过（LPC 中玩家先倒则 NPC 的 `die()` 根本不会执行）；否则
    通知玩家 `yitian/result` + `Down.mark_dead`。窗口内玩家凭真实
    伤害打死 NPC 走全局战斗死亡流程（无 `win_*` 标记，属既定限制）。
  - 玩家侧 `client_result/2`：落 `win_*`（阿大关为清
    `win_he`/`win_asan`/`win_aer`，LPC `unconcious()` 原样）、清
    `bi`、按 `$N`=玩家广播死亡文案。

  ## @todo（原世界已存在、本层不可移植/数据缺口）

  - 纯社交动作 `heng`/`grin`/`nod`/`shake`/`@@`：`emoted.c` 无定义，
    LPC 里本就静默失败，跳过（同 `Task`/`Txbw` 先例）。
  - 阿大关倚天剑：`sword->move(this_object())` + `wield()` +
    `call_out("do_unwield", 3)` 属房间物品/装备态操作，本层无 API；
    且 UCL 未把剑放进红木剑架（containment 未转换）→ 当前
    `item_instances` 恒无剑，走无剑分支；数据补齐后自动生效。
  - 阿大倒下后的 `hebiweng`/`luzhangke` 动态 spawn 与赵敏 destruct
    （`unconcious()` 尾部）：动态 NPC 生成未建模。
  - 玩家在窗口内真实打死 NPC：无 `win_*`（战斗死亡无脚本钩子，
    `combat_event.ex` 红区不碰），脚本胜负路径为既定支持路径。
  """
  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [get_session: 2, put_session: 3]

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.StatusTracker
  alias Kantele.World.NpcActions.CallOut
  alias Kantele.World.NpcActions.Down
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.NpcActions.NpcAttack
  alias Kantele.World.Room

  @bi "bi"

  # 尝试顺序（链条顺序）。每关：{LPC id, 阶段名, 取胜标记（nil=末关清标记）}
  @stages [
    {"he taichong", :he, "win_he"},
    {"a san", :asan, "win_asan"},
    {"a er", :aer, "win_aer"},
    {"a da", :ada, nil}
  ]

  # 屋内地上的倚天剑 item_id（UCL `items "yitianjian"`）
  @yitian_sword "tulong:yitianjian"

  # ---- 玩家侧入口 ----

  @impl true
  def run(conn, %{verb: "bi", room_id: room_id}) when is_binary(room_id), do: attempt(room_id, conn)
  def run(_conn, _params), do: :not_handled

  # 按链条顺序逐关试：跳过未在场/已倒下的 NPC；守卫拒了即消费命令
  # （LPC command("say") 广播 + notify_fail 私聊），全链无命中则放行全局。
  defp attempt(room_id, conn) do
    Enum.reduce_while(@stages, :not_handled, fn {id, stage, _flag}, acc ->
      npc = find_alive(room_id, id)

      cond do
        is_nil(npc) ->
          {:cont, acc}

        true ->
          case guard(stage, npc, conn) do
            {:fight} -> {:halt, begin_fight(stage, npc, room_id, conn)}
            {:refuse, say, fail} -> {:halt, refuse(conn, room_id, npc.name, say, fail)}
          end
      end
    end)
  end

  # 何太冲：兵器必须在手且为剑类。
  defp guard(:he, _npc, conn) do
    case weapon(conn) do
      %{skill_type: "sword"} ->
        {:fight}

      _ ->
        {:refuse, "我内力全失，现在只能和你比剑！", "看起来何太冲并不想跟你较量。\n"}
    end
  end

  # 阿三：win_he 标记 + 空手。
  defp guard(:asan, _npc, conn) do
    case {has_temp?(conn, "win_he"), weapon(conn)} do
      {false, _} ->
        {:refuse, "阁下是谁？为何刚才不出战，现在来趁机拣便宜。", "看起来阿三并不想跟你较量。\n"}

      {true, nil} ->
        {:fight}

      {true, w} ->
        {:refuse, "我和你比空手，请将#{w.name}放下。", "看起来阿三并不想跟你较量。\n"}
    end
  end

  # 阿二：win_asan 标记 + 空手。
  defp guard(:aer, _npc, conn) do
    case {has_temp?(conn, "win_asan"), weapon(conn)} do
      {false, _} ->
        {:refuse, "阁下是谁？为何刚才不出战，现在来趁机拣便宜。", "看起来阿二并不想跟你较量。\n"}

      {true, nil} ->
        {:fight}

      {true, w} ->
        {:refuse, "我也和你比空手，放下你的#{w.name}再说。", "看起来阿二并不想跟你较量。\n"}
    end
  end

  # 阿大：win_aer 标记 + 兵器在手。
  defp guard(:ada, _npc, conn) do
    case {has_temp?(conn, "win_aer"), weapon(conn)} do
      {false, _} ->
        {:refuse, "阁下是谁？为何刚才不出战，现在来趁机拣便宜。", "看起来阿大并不想跟你较量。\n"}

      {_, nil} ->
        {:refuse, "我只和你比兵器功夫！", "看起来阿大并不想跟你较量。\n"}

      {_, _w} ->
        {:fight}
    end
  end

  defp refuse(conn, room_id, npc_name, say, fail) do
    conn = if is_binary(say), do: Helpers.say(conn, room_id, npc_name, say), else: conn
    Helpers.render(conn, fail)
  end

  # ---- 开打（LPC begin() 成功路径，逐关文案） ----

  # 何太冲：heng（跳过）+ say 进招吧 + 两仪剑斜刺。
  defp begin_fight(:he, npc, room_id, conn) do
    conn =
      conn
      |> Helpers.say(room_id, npc.name, "进招吧！")
      |> Helpers.broadcast(
        room_id,
        "#{npc.name}话音未落，单手一抖，手中竹剑对准$N当胸斜斜刺出！正是昆仑嫡传的两仪剑法。\n"
      )
      |> Helpers.put_temp(@bi, 1)

    start(npc, room_id, conn, :he, 2)
  end

  # 阿三：grin（跳过）+ say 好！+ 大力金刚指。
  defp begin_fight(:asan, npc, room_id, conn) do
    conn =
      conn
      |> Helpers.say(room_id, npc.name, "好！")
      |> Helpers.broadcast(
        room_id,
        "#{npc.name}突然大喝一声，手作半爪，食指微曲，向$N直扑而来，架势正是少林正宗的大力金刚指！\n"
      )
      |> Helpers.put_temp(@bi, 1)

    start(npc, room_id, conn, :asan, 2)
  end

  # 阿二：nod（跳过）+ say 我出招了 + 般若掌平推。
  defp begin_fight(:aer, npc, room_id, conn) do
    conn =
      conn
      |> Helpers.say(room_id, npc.name, "我出招了。")
      |> Helpers.broadcast(
        room_id,
        "#{npc.name}双手合十，对着$N微微一揖，双掌平推，掌劲如巨浪般汹涌而出！\n"
      )
      |> Helpers.put_temp(@bi, 1)

    start(npc, room_id, conn, :aer, 2)
  end

  # 阿大：持兵器。有倚天剑在地上 →  full 倚天剑 sequence；无 → LPC 原样
  # 无任何输出直接开打。
  defp begin_fight(:ada, npc, room_id, conn) do
    conn =
      if sword_in_room?(room_id) do
        conn
        |> Helpers.broadcast(room_id, "突然赵敏喝道：“慢着！拿着倚天剑和$N斗！”\n")
        |> Helpers.broadcast(room_id, "#{npc.name}微微点了点头，道：“遵命！”\n")
        |> Helpers.broadcast(
          room_id,
          "#{npc.name}躬身上前，轻轻在红木剑架上一拍，那号称天下第一神兵的倚天剑顿时凌空跃起，飞入#{npc.name}手中。\n"
        )
        |> Helpers.broadcast(
          room_id,
          "只听“嗖”的一声破空声响，号称天下第一神兵的倚天剑已被#{npc.name}握在手中。\n"
        )
        |> Helpers.say(room_id, npc.name, "进招了。")
        |> Helpers.broadcast(
          room_id,
          "#{npc.name}仰天一声清啸，手中倚天剑寒芒顿时爆涨数倍，“刷刷刷刷”连续数剑，向$N各处要害连续刺去！身法之快，剑法之高明，的确世所罕见。\n"
        )
      else
        conn
      end
      |> Helpers.put_temp(@bi, 1)

    start(npc, room_id, conn, :ada, 3)
  end

  defp start(npc, room_id, conn, stage, strikes) do
    NpcAttack.kill_ob(npc, room_snapshot(room_id, conn.character.id))
    send_begin(npc, conn.character, stage, strikes)
    conn
  end

  # ---- NPC 侧：begin 事件 ----

  @doc "NPC 自身收到 `yitian/begin`：记 anti、按关派出招数、安排 resolve"
  def on_begin(conn, %{data: %{stage: stage, player_id: player_id, strikes: strikes}}) do
    npc = conn.character
    room_id = npc.room_id
    player = room_snapshot(room_id, player_id)

    conn = put_session(conn, "anti", player_id)

    strikes(npc, player, strikes)

    CallOut.schedule(npc, __MODULE__, :resolve, resolve_delay(stage), [player_id])
    conn
  end

  def on_begin(conn, _event), do: conn

  @doc """
  8~10 拍后脚本结算（对应 LPC 分出胜负）：玩家仍在敌人列表里（没死/
  没逃/没下线）才按 LPC `die()` 语义放倒 NPC——通知玩家 + 落死。
  """
  def resolve(conn, player_id) do
    npc = conn.character

    cond do
      dead?(npc) ->
        conn

      not enemy?(npc, player_id) ->
        # 玩家先倒/逃了：LPC 里 NPC 的 die() 不会执行
        conn

      true ->
        conn =
          notify(
            conn,
            player_id,
            stage_of(npc),
            flag_of(npc),
            death_lines(stage_of(npc), npc.name)
          )

        Down.mark_dead(conn, npc, player_id)
    end
  end

  # ---- 玩家侧：结果事件 ----

  @doc """
  玩家收到 `yitian/result`：落 `win_*`（阿大关改为清三个前置标记）、
  清 `bi`、按 `$N`=玩家广播死亡文案。
  """
  def client_result(conn, event) do
    flag = Map.get(event.data, :flag)
    clear = Map.get(event.data, :clear, [])
    lines = Map.get(event.data, :lines, [])

    conn =
      if is_binary(flag) do
        Helpers.put_temp(conn, flag, 1)
      else
        conn
      end

    conn =
      Enum.reduce(clear, conn, fn key, conn -> Helpers.delete_temp(conn, key) end)
      |> Helpers.delete_temp(@bi)

    Enum.reduce(lines, conn, fn line, conn ->
      Helpers.broadcast(conn, conn.character.room_id, line)
    end)
  end

  # ---- 各关脚本参数 ----

  defp stage_of(%{meta: %{aliases: aliases}}) do
    cond do
      "he taichong" in aliases -> :he
      "a san" in aliases -> :asan
      "a er" in aliases -> :aer
      "a da" in aliases -> :ada
      true -> nil
    end
  end

  defp stage_of(_npc), do: nil

  defp flag_of(npc) do
    case stage_of(npc) do
      :he -> "win_he"
      :asan -> "win_asan"
      :aer -> "win_aer"
      :ada -> nil
    end
  end

  defp resolve_delay(:ada), do: 10
  defp resolve_delay(_stage), do: 8

  # LPC die()/unconcious() 的死亡文案（原 `$n`=玩家 → 统一改写为 $N=玩家）。
  defp death_lines(:he, _name) do
    ["\n赵敏皱了皱眉头，低声骂道：“废物！”\n"]
  end

  defp death_lines(:asan, _name) do
    [
      "\n只听阿三几声惨嚎，全身各处关节竟然已被$N一一用重手折断，大叫一声，瘫倒在地。\n",
      "\n阿三倦缩在地，一张脸痛得全无血色，挣扎着说道：“郡主，小的无能。”，话未说完，已晕了过去。\n",
      "赵敏看了倒在地上的阿三一眼，面无表情地说道：“来人，给我抬下去。”\n",
      "赵敏转过头对$N微笑道：“不错呀，现在让阿二和你比。”\n"
    ]
  end

  defp death_lines(:aer, _name) do
    [
      "\n只听一声轰响，阿二前胸被$N打中，胸骨尽断，口中鲜血狂喷，身子如断了线的风筝一样直飞了出去，倒在地上动也不动一下。\n",
      "赵敏颇为惊讶，可还是不露声色，只是向亲兵淡淡挥手说道：“抬下去。”\n",
      "赵敏又转头对$N微笑道：“很好，还剩下个阿大，你胜过了他倚天剑你就取走吧。”\n"
    ]
  end

  defp death_lines(:ada, _name) do
    [
      "\n$N暗自摸索阿大剑招中的破绽，手中兵器挥洒，将阿大手中的倚天剑牢牢圈住，阿大顿感不妙，刚要撤剑回防，只觉胸口一阵冰凉，$N的剑身已经贯胸而入。\n",
      "$N得势不饶人，紧接着连攻出数剑，将阿大全身各处筋脉尽数削断。\n",
      "\n赵敏一张俏脸顿时惨白，叹了口气，说道：“很好，这倚天剑你就拿去吧！”\n",
      "赵敏对着$N嫣然一笑，随即轻轻伸了伸腰，轻声说道：“鹿先生，鹤先生，我累了。”\n",
      "只见赵敏身后闪出两个人影，相互使了个眼神，二话不说，对着$N直扑过来。”\n"
    ]
  end

  defp death_lines(_stage, _name), do: []

  # ---- 工具 ----

  defp strikes(_npc, _player, 0), do: :ok

  defp strikes(npc, player, n) do
    NpcAttack.strike(npc, player)
    # 台词节奏交给真实战斗 tick；这里只按关出固定数击
    if n > 1, do: strikes(npc, player, n - 1)
  end

  defp send_begin(npc, player, stage, strikes) do
    case Map.get(npc, :pid) do
      pid when is_pid(pid) ->
        send(pid, %Event{
          from_pid: self(),
          topic: "yitian/begin",
          data: %{stage: stage, player_id: player.id, strikes: strikes}
        })

        :ok

      _ ->
        {:error, :no_process}
    end
  end

  defp notify(conn, player_id, stage, flag, lines) do
    case room_snapshot(conn.character.room_id, player_id) do
      %{pid: pid} when is_pid(pid) ->
        send(pid, %Event{
          from_pid: self(),
          topic: "yitian/result",
          data: %{
            stage: stage,
            flag: flag,
            clear: stage_clear(stage),
            lines: lines
          }
        })

        conn

      _ ->
        conn
    end
  end

  # 阿大关（LPC unconcious()）：清掉三个前置 win 标记
  defp stage_clear(:ada), do: ["win_he", "win_asan", "win_aer"]
  defp stage_clear(_stage), do: []

  # 房间快照的 combat.dead 不随 NPC 自身 put_character 更新（见
  # `StatusTracker` moduledoc），故与 room.ex 四处 `dead?/1` 同构：
  # status 含「尸体」或 ETS 死亡登记。
  defp dead?(%{status: status, id: id}) when is_binary(status) and status != "",
    do: String.contains?(status, "尸体") or StatusTracker.dead?(id)

  defp dead?(%{meta: %{combat: %{dead: true}}}), do: true
  defp dead?(_character), do: false

  defp enemy?(%{meta: %{combat: %{enemies: enemies}}}, player_id) when is_list(enemies),
    do: Enum.any?(enemies, &(&1.id == player_id))

  defp enemy?(_npc, _player_id), do: false

  defp has_temp?(conn, key), do: Helpers.temp(conn, key) not in [nil, false, 0, ""]

  # LPC query_temp("weapon")：当前装备的兵器快照（无则 nil）
  defp weapon(conn) do
    case conn.character.meta do
      %{combat: %Combat{} = combat} -> Combat.weapon(combat)
      _ -> nil
    end
  end

  defp sword_in_room?(room_id) do
    Enum.any?(Room.item_instances_by_id(room_id), &(&1.item_id == @yitian_sword))
  end

  defp room_chars(room_id), do: Room.npc_characters_by_id(room_id) |> List.wrap()

  defp find_alive(room_id, id) do
    room_chars(room_id)
    |> Enum.find(fn character ->
      alias?(character, id) and not dead?(character)
    end)
  end

  defp find_alias(room_id, id), do: Enum.find(room_chars(room_id), &alias?(&1, id))

  defp room_snapshot(room_id, id), do: Enum.find(room_chars(room_id), &(Map.get(&1, :id) == id))

  defp alias?(%{meta: %{aliases: aliases}}, id) when is_list(aliases), do: id in aliases
  defp alias?(_character, _id), do: false
end
