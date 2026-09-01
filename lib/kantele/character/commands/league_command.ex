defmodule Kantele.Character.LeagueCommand do
  @moduledoc """
  结社（帮派）命令：`league <子命令>`

  对应 LPC cmds/usr/league.c

  子命令：
  - `league` / `league info [玩家|同盟]` ：查看同盟信息
  - `league member [同盟]`                ：查看成员（本派成员可查）
  - `league hatred [玩家|同盟]`           ：查看同盟仇敌
  - `league top`                          ：同盟声望排行
  - `league add <玩家>`                   ：招人（领袖或 grant>=1）
  - `league join`                         ：接受邀请加入
  - `league kick <id>`                    ：踢人（领袖或 grant>=3）
  - `league dismiss`                      ：解散同盟（领袖）
  - `league grant <id> <0-4>`             ：设定权限（领袖）
  - `league set [参数] [值]`              ：个人设置 no_kill/weiwang/follow
  - `league kill <目标>`                  ：号召成员攻击（grant>=2）
  - `league out`                          ：退出同盟（二次确认）
  - `league ?`                            ：帮助
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Presence
  alias Kantele.Character.Records
  alias Kantele.League

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    case parse_cmd(rest) do
      {:ok, verb, arg} -> dispatch(conn, verb, arg)
      :error -> render_msg(conn, "帮派指令格式错误。\n")
    end
  end

  def run(conn, %{}) do
    info(conn, nil)
  end

  defp parse_cmd(""), do: {:ok, "info", nil}

  defp parse_cmd(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [verb] -> {:ok, verb, nil}
      [verb, arg] -> {:ok, verb, arg}
      _ -> :error
    end
  end

  defp dispatch(conn, verb, arg) do
    case verb do
      "info" -> info(conn, arg)
      "member" -> member(conn, arg)
      "hatred" -> hatred(conn, arg)
      "top" -> top(conn)
      "add" -> add(conn, arg)
      "join" -> join(conn)
      "kick" -> kick(conn, arg)
      "dismiss" -> dismiss(conn, arg)
      "grant" -> grant(conn, arg)
      "set" -> set(conn, arg)
      "kill" -> kill(conn, arg)
      "out" -> out(conn)
      "check" -> check(conn)
      "?" -> help(conn)
      _ -> render_msg(conn, "无效的参数。\n")
    end
  end

  # ---- info ----

  defp info(conn, arg) do
    character = conn.character
    fname = resolve_league_name(character, arg)
    pro = if arg in [nil, ""], do: "你", else: fname

    cond do
      is_nil(fname) ->
        render_msg(conn, "你现在还没有和别人结义成盟呢。\n")

      true ->
        members = League.query_members(fname)

        cond do
          is_nil(members) ->
            render_msg(conn, "现在江湖上没有(#{fname})这个字号。\n")

          members == [] ->
            render_msg(conn, "#{pro}现在没有一个兄弟。\n")

          true ->
            render_info(conn, character, fname, members)
        end
    end
  end

  defp render_info(conn, character, fname, members) do
    leader_id = character.meta |> PlayerMeta.league() |> key_or("leader_id", "?")
    leader_name = character.meta |> PlayerMeta.league() |> key_or("leader_name", "?")

    leader = Enum.find(Presence.characters(), &(&1.id == leader_id))
    leader_name = if leader, do: leader.name, else: leader_name

    header = "\n以下是「#{fname}」的具体信息：【同盟领袖】：#{leader_name}(#{leader_id})\n\n"

    rows =
      Enum.map_join(members, "", fn id ->
        if player = Enum.find(Presence.characters(), &(&1.id == id)) do
          exp = player.meta.stats.combat_exp || 0
          score = player.meta.stats.score || 0
          weiwang = player.meta.stats.weiwang || 0
          grant = player.meta |> PlayerMeta.league() |> key_or("grant", 0)

          String.pad_trailing("  #{id}", 14) <>
            " 在线  经验：#{exp}  阅历：#{score}  威望：#{weiwang}  #{stars(grant)}\n"
        else
          "  #{id}  不在线\n"
        end
      end)

    fame = League.query_league_fame(fname)

    render_msg(
      conn,
      header <>
        rows <>
        "\n现在#{fname}中一共有#{length(members)}位兄弟，在江湖上具有 #{fame} 点声望。\n"
    )
  end

  # ---- member ----

  defp member(conn, arg) do
    character = conn.character
    fname = arg || (character |> PlayerMeta.league() |> key_or("league_name", ""))

    cond do
      fname == "" ->
        render_msg(conn, "你现在还没有加入任何一个同盟呢。\n")

      League.query_members(fname) == nil ->
        render_msg(conn, "现在江湖上没有(#{fname})这个字号。\n")

      true ->
        members = League.query_members(fname)

        if members == [] do
          render_msg(conn, "#{fname}现在人丁稀落。\n")
        else
          rows =
            Enum.map_join(members, "\n", fn id ->
              if player = Enum.find(Presence.characters(), &(&1.id == id)) do
                grant = player.meta |> PlayerMeta.league() |> key_or("grant", 0)
                "#{player.name}(#{id}) #{stars(grant)}"
              else
                "#{id}(离线)"
              end
            end)

          render_msg(conn, "#{fname}目前有以下#{length(members)}人：\n#{rows}\n")
        end
    end
  end

  # ---- hatred ----

  defp hatred(conn, arg) do
    character = conn.character
    fname = resolve_league_name(character, arg)

    if is_nil(fname) do
      render_msg(conn, "你现在还没有和别人结义成盟呢。\n")
    else
      hatred = League.query_league_hatred(fname)

      if map_size(hatred) == 0 do
        render_msg(conn, "#{fname}现在没有什么仇人。\n")
      else
        rows =
          hatred
          |> Enum.sort_by(fn {_id, [_n, lvl]} -> -lvl end)
          |> Enum.take(30)
          |> Enum.with_index(1)
          |> Enum.map_join("", fn {{id, [name, lvl]}, i} ->
            "  #{i}. #{name}(#{id})  仇恨度 #{lvl}\n"
          end)

        render_msg(conn, "目前#{fname}在江湖上的仇敌都有\n--------------------------------\n#{rows}--------------------------------\n")
      end
    end
  end

  # ---- top ----

  defp top(conn) do
    rows =
      League.ranking()
      |> Enum.with_index(1)
      |> Enum.map_join("", fn {league, i} ->
        "  #{i}. 「#{league.fname}」  威望 #{league.fame}  成员 #{length(league.member)}\n"
      end)

    render_msg(conn, "结义同盟声望排行：\n#{rows}")
  end

  # ---- add (招人) ----

  defp add(conn, arg) when is_binary(arg) and arg != "" do
    character = conn.character
    league = PlayerMeta.league(character.meta)

    cond do
      is_nil(league) ->
        render_msg(conn, "你现在还没有和任何人结义成盟呢。\n")

      not leader_or_grant?(character, league, 1) ->
        render_msg(conn, "你没有足够权限收取成员！\n")

      true ->
        target = find_player(arg)

        cond do
          is_nil(target) ->
            render_msg(conn, "#{arg} 这个人并不在线上，无法收取该成员！\n")

          PlayerMeta.league(target.meta) != nil ->
            render_msg(conn, "这个玩家已经加入了一个同盟！\n")

          League.query_members(league.league_name) != nil and
              length(League.query_members(league.league_name)) >= 30 ->
            render_msg(conn, "同盟中最多只能有三十个人！\n")

          true ->
            do_add(conn, character, target, league)
        end
    end
  end

  defp add(conn, _), do: render_msg(conn, "你要收取谁为成员？\n")

  defp do_add(conn, character, target, league) do
    case League.add_member_into_league(league.league_name, target.id) do
      :ok ->
        fname = league.league_name

        # 通知目标写入 meta.league
        send(target.pid, %Event{
          from_pid: self(),
          topic: "league/joined",
          data: %{league_name: fname, leader_id: league.leader_id, leader_name: league.leader_name}
        })

        League.add_league_fame(fname, target.meta.stats.weiwang || 0)

        render_msg(conn, "你收取了#{target.name}(#{target.id})为成员。\n")

      _ ->
        render_msg(conn, "收取失败。\n")
    end
  end

  # ---- join ----

  defp join(conn) do
    character = conn.character

    case PlayerMeta.get_temp(character.meta, "wait_reply") do
      nil ->
        render_msg(conn, "现在没有同盟邀请你加入！\n")

      leader_id ->
        target = find_player(leader_id)

        cond do
          is_nil(target) ->
            meta = PlayerMeta.delete_temp(character.meta, "wait_reply")
            new_conn = put_character(conn, %{character | meta: meta})
            save(new_conn)
            render_msg(new_conn, "刚才邀请你的人已经不在线上了！\n")

          true ->
            join_league(conn, character, target)
        end
    end
  end

  defp join_league(conn, character, leader) do
    league = PlayerMeta.league(leader.meta)

    cond do
      is_nil(league) ->
        render_msg(conn, "邀请你的同盟已不存在。\n")

      true ->
        fname = league.league_name

        case League.add_member_into_league(fname, character.id) do
          :ok ->
            new_meta =
              character.meta
              |> PlayerMeta.put_league(%{
                league_name: fname,
                leader_id: league.leader_id,
                leader_name: league.leader_name,
                grant: 0,
                set: %{no_kill: 0, weiwang: 0, follow: 0}
              })
              |> PlayerMeta.delete_temp("wait_reply")
              |> PlayerMeta.delete_temp("wait_join")

            new_conn = put_character(conn, %{character | meta: new_meta})
            save(new_conn)
            League.add_league_fame(fname, character.meta.stats.weiwang || 0)

            render_msg(new_conn, "你加入了「#{fname}」。\n")

          _ ->
            render_msg(conn, "加入失败。\n")
        end
    end
  end

  # ---- kick ----

  defp kick(conn, arg) when is_binary(arg) and arg != "" do
    character = conn.character
    league = PlayerMeta.league(character.meta)
    id = String.trim(arg)

    cond do
      is_nil(league) ->
        render_msg(conn, "你现在还没有和任何人结义成盟呢。\n")

      not leader_or_grant?(character, league, 3) ->
        render_msg(conn, "你没有足够权限开除成员！\n")

      id == character.id ->
        render_msg(conn, "自己踢自己？\n")

      league.leader_id == id ->
        render_msg(conn, "好啊，连领袖都敢踢？\n")

      true ->
        League.query_members(league.league_name) || []

        if id not in (League.query_members(league.league_name) || []) do
          render_msg(conn, "你所在同盟中没有这号人！\n")
        else
          do_kick(conn, character, league, id)
        end
    end
  end

  defp kick(conn, _), do: render_msg(conn, "你要开除哪个成员？\n")

  defp do_kick(conn, character, league, id) do
    fname = league.league_name

    kicked = find_player(id)
    penalty = if kicked, do: weiwang(kicked), else: 0

    League.remove_member_from_league(fname, id)
    League.add_league_fame(fname, -penalty)

    # 通知被踢者清除 meta.league
    if kicked do
      send(kicked.pid, %Event{from_pid: self(), topic: "league/removed", data: %{league_name: fname}})
    end

    render_msg(conn, "你开除了#{id}。\n")
  end

  # ---- dismiss ----

  defp dismiss(conn, arg) do
    character = conn.character
    league = PlayerMeta.league(character.meta)

    cond do
      is_nil(league) ->
        render_msg(conn, "你现在还没有和任何人结义成盟呢。\n")

      character.id != league.leader_id ->
        render_msg(conn, "只有同盟领袖才能解散同盟！\n")

      true ->
        fname = league.league_name

        (League.query_members(fname) || [])
        |> Enum.each(fn id ->
          if member = find_player(id) do
            send(member.pid, %Event{from_pid: self(), topic: "league/dismissed", data: %{league_name: fname}})
          end
        end)

        League.dismiss_league(fname)
        render_msg(conn, "你强行解散了#{fname}。\n")
    end
  end

  # ---- grant ----

  defp grant(conn, arg) when is_binary(arg) and arg != "" do
    character = conn.character
    league = PlayerMeta.league(character.meta)

    case String.split(String.trim(arg), ~r/\s+/, parts: 2) do
      [id, lvl_str] ->
        case Integer.parse(lvl_str) do
          {lvl, ""} when lvl in 0..4 ->
            do_grant(conn, character, league, id, lvl)

          _ ->
            render_msg(conn, "指令格式：league grant [id] [权限等级(0--4)]。\n")
        end

      _ ->
        render_msg(conn, "指令格式：league grant [id] [权限等级(0--4)]。\n")
    end
  end

  defp grant(conn, _), do: render_msg(conn, "指令格式：league grant [id] [权限等级(0--4)]。\n")

  defp do_grant(conn, character, league, id, lvl) do
    cond do
      is_nil(league) ->
        render_msg(conn, "你现在还没有和任何人结义成盟呢。\n")

      character.id != league.leader_id ->
        render_msg(conn, "只有同盟领袖才能使用该指令！\n")

      id == character.id ->
        render_msg(conn, "你已经是领袖了！\n")

      (League.query_members(league.league_name) || []) |> Enum.member?(id) |> Kernel.not() ->
        render_msg(conn, "看清楚了，他不是你的成员！\n")

      true ->
        if target = find_player(id) do
          send(target.pid, %Event{from_pid: self(), topic: "league/grant", data: %{grant: lvl}})
        end

        render_msg(conn, "你修改了#{id}的权限为#{stars(lvl)}。\n")
    end
  end

  # ---- set ----

  defp set(conn, nil) do
    character = conn.character
    set = character.meta |> PlayerMeta.league() |> league_set()

    render_msg(
      conn,
      "你目前设置如下：\nno_kill == #{set.no_kill}\nweiwang == #{set.weiwang}％\nfollow == #{set.follow}\n"
    )
  end

  defp set(conn, arg) do
    character = conn.character

    case String.split(String.trim(arg), ~r/\s+/, parts: 2) do
      [param, val_str] ->
        case Integer.parse(val_str) do
          {val, ""} ->
            if param in ["no_kill", "weiwang", "follow"] do
              val = if val > 100, do: 100, else: max(val, 0)
              update_setting(conn, character, param, val)
            else
              render_msg(conn, "指令格式：league set <参数> <变量>。\nno_kill / weiwang / follow\n")
            end

          _ ->
            render_msg(conn, "指令格式：league set <参数> <变量>。\n")
        end

      _ ->
        render_msg(conn, "指令格式：league set <参数> <变量>。\n")
    end
  end

  defp update_setting(conn, character, param, val) do
    case PlayerMeta.league(character.meta) do
      nil ->
        render_msg(conn, "你现在还没有和别人结义成盟呢。\n")

      league ->
        set = Map.get(league, :set, %{no_kill: 0, weiwang: 0, follow: 0})
        new_league = %{league | set: Map.put(set, String.to_atom(param), val)}
        meta = PlayerMeta.put_league(character.meta, new_league)
        new_conn = put_character(conn, %{character | meta: meta})
        save(new_conn)
        render_msg(new_conn, "OK！\n")
    end
  end

  # ---- kill (号召) ----

  defp kill(conn, arg) when is_binary(arg) and arg != "" do
    character = conn.character
    league = PlayerMeta.league(character.meta)

    cond do
      is_nil(league) ->
        render_msg(conn, "你现在还没有和任何人结义成盟呢。\n")

      not leader_or_grant?(character, league, 2) ->
        render_msg(conn, "你没有足够权限号召同盟成员参与战斗！\n")

      true ->
        target = Enum.find(Presence.characters(), &(&1.id == arg or String.starts_with?(&1.name, arg)))

        if is_nil(target) do
          render_msg(conn, "你想攻击谁？\n")
        else
          render_msg(conn, "你振臂一呼：「#{league.league_name}」的兄弟们，一起对付#{target.name}！\n")
        end
    end
  end

  defp kill(conn, _), do: render_msg(conn, "你想攻击谁？\n")

  # ---- out ----

  defp out(conn) do
    character = conn.character
    league = PlayerMeta.league(character.meta)

    cond do
      is_nil(league) ->
        render_msg(conn, "你现在还没有和任何人结义成盟呢。\n")

      PlayerMeta.get_temp(character.meta, "pending/out_league") ->
        fname = league.league_name
        penalty = leave_penalty(fname)
        League.add_league_fame(fname, -penalty)

        League.remove_member_from_league(fname, character.id)

        meta =
          character.meta
          |> PlayerMeta.put_league(nil)
          |> PlayerMeta.delete_temp("pending/out_league")

        new_conn = put_character(conn, %{character | meta: meta})
        save(new_conn)
        render_msg(new_conn, "你背弃了「#{fname}」，从此不再是其成员。\n")

      true ->
        meta = PlayerMeta.put_temp(character.meta, "pending/out_league", 1)
        new_conn = put_character(conn, %{character | meta: meta})
        save(new_conn)
        render_msg(new_conn, "你真的想要背弃当初的结义好友吗？这样做会降低声望。如果确定了，就再输入一次 league out 命令。\n")
    end
  end

  # ---- check ----

  defp check(conn) do
    character = conn.character

    case PlayerMeta.league(character.meta) do
      nil ->
        render_msg(conn, "")

      league ->
        members = League.query_members(league.league_name)

        cond do
          is_nil(members) or members == [] ->
            meta = PlayerMeta.put_league(character.meta, nil)
            new_conn = put_character(conn, %{character | meta: meta})
            save(new_conn)
            render_msg(new_conn, "【离线通告】你离线时所在同盟已解散！\n")

          character.id not in members ->
            meta = PlayerMeta.put_league(character.meta, nil)
            new_conn = put_character(conn, %{character | meta: meta})
            save(new_conn)
            render_msg(new_conn, "【离线通告】你离线时已从同盟被开除！\n")

          true ->
            render_msg(conn, "")
        end
    end
  end

  # ---- help ----

  defp help(conn) do
    render_msg(
      conn,
      """
      指令格式: league info [玩家] | hatred [玩家] | member [同盟名字] | top

      info     ：查看同盟中的人物，成员状态，声望。
      hatred   ：查看同盟的仇恨对象。
      member   ：查看某个同盟的成员。
      top      ：查看结义同盟的声望排名。

      add      ：增加一个同盟成员。
      join     ：接受同盟邀请。
      kick     ：开除一个同盟成员。
      dismiss  ：强行解散当前同盟。
      grant    ：修改成员权限（0-4）。
      set      ：参数设置（no_kill / weiwang / follow）。
      kill     ：号召同一房间的成员攻击某一目标。
      out      ：退出同盟。
      ?        ：查看有关同盟指令的信息。
      """
    )
  end

  # ---- helpers ----

  defp resolve_league_name(character, arg) do
    if arg in [nil, ""] do
      character |> PlayerMeta.league() |> key_or("league_name", nil)
    else
      # LPC：巫师可查任意同盟；此处限制查询自身或在线玩家所在的同盟
      character |> PlayerMeta.league() |> key_or("league_name", nil)
    end
  end

  defp leader_or_grant?(character, league, min_grant) do
    character.id == league.leader_id or (PlayerMeta.league(character.meta) |> key_or("grant", 0)) >= min_grant
  end

  defp key_or(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp key_or(_map, _key, default), do: default

  defp league_set(nil), do: %{no_kill: 0, weiwang: 0, follow: 0}
  defp league_set(%{set: set}) when is_map(set), do: Map.merge(%{no_kill: 0, weiwang: 0, follow: 0}, set)
  defp league_set(_), do: %{no_kill: 0, weiwang: 0, follow: 0}

  defp find_player(name) do
    Enum.find(Presence.characters(), fn c ->
      c.id == name or String.starts_with?(c.name, name)
    end)
  end

  defp weiwang(%{meta: %{stats: %{weiwang: v}}}), do: v || 0
  defp weiwang(_), do: 0

  defp leave_penalty(fname) do
    w = 0
    fame = League.query_league_fame(fname)
    if w < div(fame, 10), do: div(fame, 10), else: w
  end

  defp stars(0), do: ""
  defp stars(1), do: "★"
  defp stars(2), do: "★★"
  defp stars(3), do: "★★★"
  defp stars(g) when g >= 4, do: "★★★★"
  defp stars(_), do: ""

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end