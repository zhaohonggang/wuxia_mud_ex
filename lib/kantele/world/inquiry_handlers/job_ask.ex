defmodule Kantele.World.InquiryHandlers.JobAsk do
  @moduledoc """
  打工领活问询（kind = "job_ask"）的共享处理器，对应 A-5-b 的 11 个占位符。

  ## 覆盖范围

  | profile | LPC 源 | 关键词 | 写入 temp |
  |---|---|---|---|
  | `city_ping` | `d/city/npc/ping.c:113-145` `ask_job()` | 配药 / 工作 / job | `job/peiyao` |
  | `city_shutong` | `d/city/npc/shutong.c:45-83` `ask_job()` | 抄书 / 工作 / job | `job/copy` |
  | `chengdu_chuniang` | `d/chengdu/npc/chuniang.c:67-105` `ask_job()` | job / 工作 | `job/cook` |

  `city_ping` 的判定链直接复用 `Kantele.NPC.CityPing.check/3` + `execute/3`
  （第 55 批已实现的 AskHandler），不再复制一份阈值与文案。

  ## 门序

  `city_shutong`（LPC 原序）：

  1. 已领 `job/copy` → 「让你抄的书你抄完了？」
  2. `combat_exp < 1200` → 经验太差
  3. `combat_exp > 8000` → 大侠别抄书
  4. `qi < 20` → 脸色不行
  5. `jing < 10` → 精神不行
  6. `query_int() < 25 且 literate < 20` → 不太聪明
  7. 同房间已有别人领 `job/copy` → 「我这已经有…在干活了，你等等吧。」
  8. 成功：写 temp，回「好，你就帮我抄书(copy)吧！笔墨纸砚在这儿。」

  `chengdu_chuniang`（LPC 原序）：

  1. 非女性 → 「你一个大老爷们，来炒什么菜啊？」
  2. `combat_exp < 10000` → 端得动盘子么
  3. `jing < 100` → 休息会儿
  4. `combat_exp > 200000 且 mark/job_cook > 1000` → 折杀小的
  5. `cooking < 60` → 手艺太差
  6. `query_skill_mapped("cooking") != "chuancai-jiyi"` → 亮出川菜活儿
  7. 成功：写 temp，回「好吧，你就帮我炒菜(cook)吧！菜在这儿，灶台在那边。」

  ## 已知端口差异

  - LPC 的 `interactive(me)` 门（非玩家返回 `...`）未建模：AskCommand 只会由真实
    玩家触发，该门在当前运行时恒真。
  - LPC 书童的同房占用门还比较 `query_ip_number()`；引擎没有角色 IP 字段，
    本实现按「同房间且 temp 非空」判定，比 LPC 稍严，但保留了门序与文案。
  - 厨娘的同类占用门在 LPC 源码中已被注释掉，本实现不补该门。
  - 本 handler 只负责 ask_job 领活；`copy` / `cook` 的多轮干活结算不在本片范围。
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.NPC.CityPing
  alias Kantele.World.Room

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      case profile(config) do
        "city_ping" -> city_ping(conn, character)
        "city_shutong" -> city_shutong(conn, character)
        "chengdu_chuniang" -> chengdu_chuniang(conn, character)
        _ -> conn
      end
    end
  end

  def run(conn, _config, _data), do: conn

  # ---- profile: 平一指 ----

  defp city_ping(conn, character) do
    npc = %{name: "平一指"}

    case CityPing.check(character, npc, "job") do
      :ok ->
        {:ok, text, updated} = CityPing.execute(character, npc, "job")
        conn |> put_character(updated) |> reply_raw(text)

      {:error, text} ->
        reply_raw(conn, text)
    end
  end

  # ---- profile: 书童 ----

  defp city_shutong(conn, character) do
    meta = meta(character)
    temp = Map.get(meta, :temp) || %{}
    stats = stats(character)
    exp = Map.get(stats, :combat_exp, 0) || 0

    cond do
      present_temp?(temp, "job/copy") ->
        reply(conn, "让你抄的书你抄完了？")

      exp < 1200 ->
        reply(conn, "虽然在这里只是抄抄书，可是你经验太差，遇到流氓捣乱可不好！")

      exp > 8000 ->
        reply(conn, "大侠你还是别抄书了，我可不敢劳您大架。")

      vital(character, :qi) < 20 ->
        reply(conn, "我看你脸色不行啊，先歇会儿吧，我可不想抄书抄出人命来。")

      vital(character, :jing) < 10 ->
        reply(conn, "我看你精神不行啊，能抄得了书么？")

      int_of(stats) < 25 and skill_level(stats, "literate") < 20 ->
        reply(conn, "您好像稍稍有那么一点点不太聪明呀！")

      occupant = room_occupant(conn, character.id, "job/copy") ->
        reply(conn, "我这已经有#{occupant}在干活了，你等等吧。")

      true ->
        conn
        |> put_temp("job/copy", 1)
        |> reply("好，你就帮我抄书(copy)吧！笔墨纸砚在这儿。")
    end
  end

  # ---- profile: 厨娘 ----

  defp chengdu_chuniang(conn, character) do
    meta = meta(character)
    stats = stats(character)
    exp = Map.get(stats, :combat_exp, 0) || 0
    marks = Map.get(meta, :marks) || %{}
    job_count = Map.get(marks, "job_cook", 0) || 0

    cond do
      gender(character) != "女性" ->
        reply(conn, "你一个大老爷们，来炒什么菜啊？")

      exp < 10_000 ->
        reply(conn, "呦，你这点本事啊，端得动盘子么？")

      vital(character, :jing) < 100 ->
        reply(conn, "你还是休息会儿吧，小心把身子累垮了！")

      exp > 200_000 and job_count > 1000 ->
        reply(conn, "这位女侠，你这不是折杀小的吗！你还是去前面用餐吧！饭菜马上就好！")

      skill_level(stats, "cooking") < 60 ->
        reply(conn, "你的炒菜手艺那么差，那里能帮我？")

      Stats.mapped(stats, "cooking") != "chuancai-jiyi" ->
        reply(conn, "我说你知不知道来的客人可都是吃川菜的，亮出你川菜的活儿再说！")

      true ->
        conn
        |> put_temp("job/cook", 1)
        |> reply("好吧，你就帮我炒菜(cook)吧！菜在这儿，灶台在那边。")
    end
  end

  # ---- helpers ----

  defp profile(config) do
    Map.get(config, "profile") || Map.get(config, :profile) || "city_ping"
  end

  defp meta(%{meta: meta}) when is_map(meta), do: meta
  defp meta(_), do: %{}

  defp stats(character) do
    case Map.get(meta(character), :stats) do
      %Stats{} = stats -> stats
      stats when is_map(stats) -> stats
      _ -> %Stats{mapped: %{}, skills: %{}, tattoo: %{}, reborn: %{}}
    end
  end

  defp vital(character, key) do
    case Map.get(meta(character), :vitals) do
      %Vitals{} = vitals -> Map.get(vitals, key, 0) || 0
      vitals when is_map(vitals) -> Map.get(vitals, key, 0) || 0
      _ -> 0
    end
  end

  defp int_of(%Stats{} = stats), do: Stats.query_int(stats)
  defp int_of(stats) when is_map(stats), do: Map.get(stats, :int, 0) || 0

  defp skill_level(stats, skill), do: Stats.skill(stats, skill) || 0

  defp gender(character) do
    meta = meta(character)
    env = Map.get(meta, :env) || Map.get(meta, "env") || %{}

    Map.get(env, :gender) || Map.get(env, "gender") || Map.get(meta, :gender) ||
      Map.get(character, :gender)
  end

  defp present_temp?(temp, key) do
    case Map.get(temp, key) do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  # 房间快照里其他角色已领同一活计即占用。LPC 还要求同 IP；引擎无 IP 字段。
  defp room_occupant(conn, asker_id, job_key) do
    asker_id = to_string(asker_id)

    Enum.find_value(Room.characters_for_conn(conn), fn other ->
      other_id = to_string(Map.get(other, :id) || "")

      if other_id != "" and other_id != asker_id do
        other_meta = Map.get(other, :meta) || %{}
        temp = Map.get(other_meta, :temp) || Map.get(other_meta, "temp") || %{}

        if present_temp?(temp, job_key) do
          Map.get(other, :name) || other_id
        end
      end
    end)
  end

  defp put_temp(conn, key, value) do
    character = current(conn)
    updated = %{character | meta: PlayerMeta.put_temp(character.meta, key, value)}
    put_character(conn, updated)
  end

  defp reply(conn, text), do: reply_raw(conn, text <> "\n")

  defp reply_raw(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply_raw(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
