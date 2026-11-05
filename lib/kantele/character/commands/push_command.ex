defmodule Kantele.Character.PushCommand do
  @moduledoc """
  推人命令：`push <人物> to <方向>`

  对应 LPC `cmds/std/push.c`。把妨碍的同房间玩家沿出口推入相邻房间。

  ## 移植范围（LPC 门控逐条落地）

  1. `sscanf("%s to %s")` 格式门；
  2. `default_where` 方向别名归一（n/s/e/w/nu/…/u/d）；
  3. 当前房间 `exits` 里必须有该方向；
  4. 目标房间 `no_fight`；
  5. `present(who, 目标房间)` 找人、`is_character()`；
  6. `target->is_fighting()`；
  7. `living(target)`（尸体/幽魂拒）；
  8. `playerp(target)`（仅玩家可被推，NPC 不可）；
  9. `valid_leave(target, where)`（本端口走 `Kantele.World.exit_veto_message/2` 回查
     房间 `exit_vetoes` 的 `notify_fail` 原文）；
  10. 推者体力：`qi >= 150`、`neili >= 100`、`force` 技能 >= 100；
  11. 目标 `force` >= 150 → 内功根基扎实，推不动；
  12. 成功：目标 `move(env_to)`（本端口发 `character/teleport` 事件让目标进程
      自行瞬移）、目标 `start_busy(5)`；推者 `receive_damage("qi", 100)`、
      `add("neili", -50)`、`start_busy(1)`。

  ## 与 LPC 的差异（引擎模型所限）

  - Ex 无巫师等级（wizard_level）体系，故 `wiz_push` / `wiz_level` 比较全部省略，
    体力消耗与 `force` 门控对所有角色一致生效；
  - 目标跨房间移位不由推者进程直接执行（引擎要求移位由角色自己的 conn 完成），
    改为向目标 pid 发 `character/teleport` 事件（见 `Kantele.Character.TeleportEvent`），
    目标进程收到后自行 `Teleport.teleport/2`；
  - `query_temp("on_baitan")` / `query("doing")` 等 LPC temp 字段未建模，已省略。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room

  # LPC default_where：短别名 → 出口名
  @where_aliases %{
    "n" => "north",
    "s" => "south",
    "e" => "east",
    "w" => "west",
    "nu" => "northup",
    "su" => "southup",
    "eu" => "eastup",
    "wu" => "westup",
    "nd" => "northdown",
    "sd" => "southdown",
    "ed" => "eastdown",
    "wd" => "westdown",
    "ne" => "northeast",
    "nw" => "northwest",
    "se" => "southeast",
    "sw" => "southwest",
    "u" => "up",
    "d" => "down"
  }

  # LPC default_dirs：出口名 → 中文去向
  @dirs %{
    "north" => "北边",
    "south" => "南边",
    "east" => "东边",
    "west" => "西边",
    "northup" => "北边",
    "southup" => "南边",
    "eastup" => "东边",
    "westup" => "西边",
    "northdown" => "北边",
    "southdown" => "南边",
    "eastdown" => "东边",
    "westdown" => "西边",
    "northeast" => "东北",
    "northwest" => "西北",
    "southeast" => "东南",
    "southwest" => "西南",
    "up" => "上面",
    "down" => "下面",
    "enter" => "里面",
    "in" => "里面",
    "out" => "外面"
  }

  # LPC default_undirs：出口名 → 中文来向（目标视角）
  @undirs %{
    "south" => "北边",
    "north" => "南边",
    "west" => "东边",
    "east" => "西边",
    "southup" => "北边",
    "northup" => "南边",
    "westup" => "东边",
    "eastup" => "西边",
    "southdown" => "北边",
    "northdown" => "南边",
    "westdown" => "东边",
    "eastdown" => "西边",
    "southwest" => "东北",
    "southeast" => "西北",
    "northwest" => "东南",
    "northeast" => "西南",
    "down" => "上面",
    "up" => "下面",
    "out" => "里面",
    "in" => "外面",
    "enter" => "外面"
  }

  @doc """
  解析 `push <人物> to <方向>`。

  LPC 的 `sscanf(arg, "%s to %s", who, where_temp)` 只接受两个以空白分隔的词，
  故这里同样不允许人物/方向里带空格。方向大小写不敏感。
  """
  def parse(rest) when is_binary(rest) do
    case Regex.run(~r/^\s*(\S+)\s+to\s+(\S+)\s*$/, rest) do
      [_, who, where] -> {:ok, who, String.downcase(where)}
      _ -> {:error, :format}
    end
  end

  def parse(_), do: {:error, :format}

  @doc "LPC `default_where`：短别名归一为出口名，未登记的按原样透传。"
  def normalize_direction(where), do: Map.get(@where_aliases, where, where)

  @doc "LPC `default_dirs`：去向中文。"
  def direction_name(where), do: Map.get(@dirs, where, where)

  @doc "LPC `default_undirs`：来向中文（目标视角）。"
  def opposite_name(where), do: Map.get(@undirs, where, where)

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    case parse(rest) do
      {:error, :format} -> usage(conn)
      {:ok, who, where_arg} -> attempt(conn, who, normalize_direction(where_arg))
    end
  end

  def run(conn, %{}), do: usage(conn)

  defp attempt(conn, who, where) do
    me = conn.character

    case exit_room(exits_of(snapshot(conn, me.room_id)), where) do
      nil ->
        reject(conn, "没有这个方向。\n")

      target_room_id ->
        adjudicate(conn, me, who, where, target_room_id)
    end
  end

  defp adjudicate(conn, me, who, where, target_room_id) do
    target =
      characters_of(snapshot(conn, target_room_id))
      |> Enum.find(fn character ->
        character.pid != me.pid and Room.NameMatch.matches?(character, who)
      end)

    cond do
      "no_fight" in room_flags(conn, target_room_id) ->
        reject(conn, "这里不是你嚣张的地方。\n")

      is_nil(target) ->
        reject(conn, "你要推开谁？\n")

      not is_character?(target) ->
        reject(conn, "看清楚一点，那并不是生物。\n")

      fighting?(target) ->
        reject(conn, "人家现在正在打架呢，你想去找扁啊。\n")

      dead?(target) ->
        reject(conn, "这人现在没有知觉，你还是扶着人家走吧。\n")

      not player?(target) ->
        reject(conn, "你看了看这个人，没敢动。\n")

      veto = veto_message(conn, me.room_id, where) ->
        reject(conn, to_string(veto))

      qi(me) < 150 ->
        reject(conn, "你气力不佳，推不动别人。\n")

      neili(me) < 100 ->
        reject(conn, "你内力不济，推不动别人。\n")

      force_skill(me) < 100 ->
        reject(conn, "你内功修为有限，没有到达举轻若重的地步。\n")

      true ->
        execute(conn, me, target, where, target_room_id)
    end
  end

  # ---- 推人执行（LPC main 后半段）----

  defp execute(conn, me, target, where, target_room_id) do
    dir = direction_name(where)
    undir = opposite_name(where)

    opening =
      Enum.random([
        "{npc}清咳一声，喝道：「让开了！」顺势就把{target}往{dir}一挤。\n",
        "{npc}皱了皱眉头，恼道：「闪开！」随手便把{target}往{dir}一推。\n",
        "{npc}双目一瞪，喝道：「还不快快给我闪开？」说罢把{target}往{dir}推去。\n"
      ])
      |> String.replace("{npc}", me.name)
      |> String.replace("{target}", target.name)
      |> String.replace("{dir}", dir)

    # LPC：非巫师消耗 qi 100 / neili 50，无论推成与否都扣（main 段在 force 门控前已扣）
    me = exert(conn, me)

    cond do
      force_skill(target) >= 150 ->
        # 目标内功根基扎实，推不动
        full =
          opening <>
          "{npc}用力推了推，只觉得好象撞到了一堵墙一样。\n"
          |> String.replace("{npc}", me.name)

        broadcast(me.room_id, full, me.pid)

        conn
        |> put_character(me)
        |> render(CommandView, "text", %{text: full})
        |> prompt(CommandView, "prompt", %{})

      true ->
        # 推成功：目标移入目标房间
        full =
          opening <>
          "顿时只见{npc}这一下把{target}「嘟噜嘟噜」的推了开去。\n"
          |> String.replace("{npc}", me.name)
          |> String.replace("{target}", target.name)

        broadcast(me.room_id, full, me.pid)

        # LPC target->move(env_to)：目标进程没有推者的 conn，发 character/teleport 事件
        # 让目标进程自己走 Teleport.teleport/2。
        send(target.pid, %Kalevala.Event{
          from_pid: self(),
          topic: "character/teleport",
          data: %{room_id: target_room_id}
        })

        target_room_text =
          "只见{target}跌跌撞撞的从{undir}晃了过来。\n"
          |> String.replace("{target}", target.name)
          |> String.replace("{undir}", undir)

        broadcast(target_room_id, target_room_text, target.pid)

        conn
        |> put_character(me)
        |> render(CommandView, "text", %{text: full})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # LPC 收尾：me->receive_damage("qi", 100); me->add("neili", -50); me->start_busy(1)
  # 注意：Teleport 可能已改写 conn.private.update_character，取最新角色再叠加。
  defp exert(conn, me) do
    character = Map.get(conn.private, :update_character) || conn.character || me
    meta = character.meta

    combat = Combat.start_busy(meta.combat || Combat.new(), 1)
    vitals =
      (meta.vitals || Vitals.new())
      |> Vitals.damage(:qi, 100)
      |> then(&%{&1 | neili: max(&1.neili - 50, 0)})

    new_meta = %{meta | combat: combat, vitals: vitals}
    %{character | meta: new_meta}
  end

  # ---- 消息原语 ----

  defp broadcast(room_id, text, except_pid) do
    Room.tell_room(%Room{id: room_id}, text, except_pid)
    :ok
  rescue
    _ -> :ok
  end

  # ---- 世界数据查询（单测可从 conn.private 注入，避免依赖 ZoneCache / 房间进程） ----

  defp room_flags(conn, room_id) do
    case Map.get(conn.private, :room_flags) do
      fun when is_function(fun, 1) -> fun.(room_id)
      flags when is_list(flags) -> flags
      _ -> Kantele.World.room_flags(room_id)
    end
  end

  defp veto_message(conn, room_id, where) do
    case Map.get(conn.private, :exit_vetoes) do
      fun when is_function(fun, 2) -> fun.(room_id, where)
      map when is_map(map) -> Map.get(map, {room_id, where}) || Map.get(map, where)
      _ -> Kantele.World.exit_veto_message(room_id, where)
    end
  end

  # ---- 房间快照（单测可从 conn.private 注入，避免起真房间进程） ----

  defp snapshot(conn, room_id) do
    private = conn.private || %{}
    cond do
      room_id == conn.character.room_id and is_map(Map.get(private, :room)) ->
        Map.get(private, :room)

      is_map(Map.get(Map.get(private, :rooms, %{}) || %{}, room_id)) ->
        Map.get(Map.get(private, :rooms, %{}), room_id)

      true ->
        Room.snapshot(room_id)
    end
  end

  defp exits_of(snapshot) when is_map(snapshot) do
    get_in(snapshot, [:attrs, "exits"]) ||
      Map.get(snapshot, :exits) ||
      Map.get(snapshot, "exits") ||
      %{}
  end

  defp exits_of(_), do: %{}

  defp exit_room(exits, where) when is_map(exits) do
    Enum.find_value(exits, fn {key, value} ->
      if to_string(key) == where, do: value
    end)
  end

  defp exit_room(_, _where), do: nil

  defp characters_of(%{private: %{characters: characters}}) when is_list(characters),
    do: characters

  defp characters_of(%{characters: characters}) when is_list(characters), do: characters
  defp characters_of(_), do: []

  # ---- LPC 判定 ----

  defp is_character?(character), do: Map.has_key?(character, :name)

  defp fighting?(character) do
    combat = Map.get(character.meta || %{}, :combat) || Combat.new()
    Combat.fighting?(combat)
  end

  defp dead?(target) do
    attrs = target.attributes || %{}
    status = Map.get(target, :status)

    attrs["ghost"] == true or
      Map.get(attrs, "not_living") == true or
      (is_binary(status) and String.contains?(status, "尸体"))
  end

  defp player?(%{meta: %PlayerMeta{}}), do: true
  defp player?(_), do: false

  defp qi(character) do
    vitals = Map.get(character.meta || %{}, :vitals)
    value = if vitals, do: Map.get(vitals, :qi), else: nil
    value || Map.get(character.attributes || %{}, "qi") || 0
  end

  defp neili(character) do
    vitals = Map.get(character.meta || %{}, :vitals)
    value = if vitals, do: Map.get(vitals, :neili), else: nil
    value || Map.get(character.attributes || %{}, "neili") || 0
  end

  defp force_skill(character) do
    stats = Map.get(character.meta || %{}, :stats)
    case stats do
      %Stats{} -> Stats.skill(stats, "force")
      _ -> 0
    end
  end

  # ---- 输出 ----

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：push <人物> to <方向>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
