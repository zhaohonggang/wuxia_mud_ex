defmodule Kantele.World.InquiryHandlers.BeijingReward do
  @moduledoc """
  北京领赏问询（A-5-c C4，`kind = "beijing_reward"`）。

  镜像 LPC `d/beijing/npc/kangxi.c:55-113` `ask_reward()`（外敌入侵全歼后的
  殿试领赏链；御前侍卫 `yuqian1` 的传送链为 C5，稍后并入本 handler）。

  ## 门序（kangxi.c 原序，文案逐字）

  1. 康熙不在皇宫大殿（`npc_room_id != "beijing:hg"`）→
     `say 怪哉，朕如何不在皇宫！` + `message_vision("$N急急忙忙地离开了。")`
     + 康熙 `move("/d/beijing/hg")`（经 `npc/goto` 事件让 NPC 进程自移），
     不出题。
  2. 无入侵 record（`Invasion.record().exists == false`）→
     `say 如今并无异族联军入侵呀！`
  3. 未全歼（`all_killed == false`）→ `say 朕并未恩准赏赐，尔等速速离去！`
  4. 玩家 `waidi/born_time != record/born_time` → `say 尔之赏赐已过期了！`
  5. 成功：三段 say（含 `RANK_D` 敬称）→ `set("waidi/word", 词池随机词)`
     → `write(bitmap_font(word, 16) <> "\\n")`（点阵谜面，仅问询者可见）。

  作答由 `Kantele.Character.AnswerCommand` 的殿试路径处理（`do_answer`）。

  词池见 `Kantele.NPC.KangxiWords`（216 项含重复权重）。
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Teleport
  alias Kantele.NPC.KangxiWords
  alias Kantele.World.BitmapFont
  alias Kantele.World.Invasion
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  @hg_room "beijing:hg"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      case Map.get(config, "profile") do
        "kangxi" -> kangxi(conn, character, data)
        "yuqian" -> yuqian(conn, character, data)
        _ -> conn
      end
    end
  end

  def run(conn, _config, _data), do: conn

  # ---- 康熙 ask_reward（kangxi.c:55-113） ----

  defp kangxi(conn, character, data) do
    npc_name = Map.get(data, :npc_name) || "康熙大帝"
    room_id = Map.get(data, :npc_room_id)

    cond do
      # 门 1：environment != /d/beijing/hg → 自嘲 + 移驾皇宫（不出题）
      room_id != @hg_room ->
        conn
        |> npc_say(room_id, npc_name, "怪哉，朕如何不在皇宫！")
        |> npc_leaves_vision(room_id)
        |> npc_goto_hg(data)
        |> prompt_quiet()

      true ->
        kangxi_gates(conn, character, data, npc_name, room_id)
    end
  end

  defp kangxi_gates(conn, character, _data, npc_name, room_id) do
    record = Invasion.record()
    waidi = waidi_of(character)

    cond do
      # 门 2：! find_object(INVASIOND) || ! INVASIOND->query("record")
      not Map.get(record, :exists) ->
        conn
        |> npc_say(room_id, npc_name, "如今并无异族联军入侵呀！")
        |> prompt_quiet()

      # 门 3：! record/all_killed
      not Map.get(record, :all_killed) ->
        conn
        |> npc_say(room_id, npc_name, "朕并未恩准赏赐，尔等速速离去！")
        |> prompt_quiet()

      # 门 4：waidi/born_time != record/born_time
      Map.get(waidi, :born_time) != Map.get(record, :born_time) ->
        conn
        |> npc_say(room_id, npc_name, "尔之赏赐已过期了！")
        |> prompt_quiet()

      # 成功链：三段 say + set waidi/word + write(bitmap_font)
      true ->
        word = KangxiWords.random()

        conn
        |> npc_say(room_id, npc_name, "原来是抗击异族联军的义士，不错不错！")
        |> npc_say(
          room_id,
          npc_name,
          "朕一生最赏识的便是文武双全的能人志士，这位" <>
            Helpers.respect(character) <>
            "杀敌勇猛，足见武艺出众，\n              但朕尚要出道殿试之题，看看你的文采若何。"
        )
        |> npc_say(room_id, npc_name, "你看看朕写的这两个是什么字？(可用answer xxx 作答)")
        |> set_waidi_word(character, word, npc_name, room_id)
        |> reply_bitmap(word)
    end
  end

  # message_vision("$N急急忙忙地离开了。\n", this_object())：$N = 康熙本人
  defp npc_leaves_vision(conn, room_id) do
    if is_binary(room_id) do
      RoomHelpers.broadcast_vision(conn, room_id, "{npc}急急忙忙地离开了。\n")
    else
      conn
    end
  end

  # this_object()->move(...)：NPC 进程自移（玩家进程无法代移）
  defp npc_goto_hg(conn, data) do
    npc_goto(conn, data, @hg_room)
  end

  # 让 NPC 进程自移到指定房间（npc/goto 事件，Teleport 复用）
  defp npc_goto(conn, data, room_id) do
    case Map.get(data, :npc_pid) do
      pid when is_pid(pid) ->
        send(pid, %Kalevala.Event{
          from_pid: self(),
          topic: "npc/goto",
          data: %{room_id: room_id}
        })

        conn

      _ ->
        conn
    end
  end

  # ---- 御前侍卫护送链（yuqian1.c:65-100 ask_reward，A-5-c C5） ----

  # 门序（yuqian1.c 原序，文案逐字）：
  # 1. 玩家有 killer condition → `return 1`（无输出，静默）；
  # 2. 无 record → say 如今并无异族联军入侵呀！
  # 3. 未全歼 → say 圣上并未恩准赏赐，尔等速速离去！
  # 4. waidi/born_time != record/born_time → say 你的赏赐已经过期了！
  # 5. 玩家已在皇宫 → say 你快快向皇上领赏吧！
  # 6. 护送：两段 say → vision（$N/$n=侍卫/玩家）→ 玩家 move(hg) +
  #    侍卫 move(hg) → say → vision（离去）→ 侍卫 move(startroom=原房间)
  #    → vision（归来）。
  # 注：LPC `query("startroom")` 未显式 set → 等价于侍卫当前所在房间
  # （加载/出生房间），故回程用问询时的 npc_room_id。
  defp yuqian(conn, character, data) do
    npc_name = Map.get(data, :npc_name) || "御前侍卫"
    room_id = Map.get(data, :npc_room_id)
    asker_name = Map.get(data, :asker_name) || character.name

    if killer_condition?(conn) do
      # yuqian1.c:69 `if (me->query_condition("killer")) return 1;` 无输出
      conn
    else
      yuqian_gates(conn, character, data, npc_name, room_id, asker_name)
    end
  end

  defp killer_condition?(conn) do
    session = Map.get(conn, :session) || %{}

    case Map.get(session, "conditions") do
      conds when is_map(conds) -> Map.has_key?(conds, "killer")
      _ -> false
    end
  end

  defp yuqian_gates(conn, character, data, npc_name, room_id, asker_name) do
    record = Invasion.record()
    waidi = waidi_of(character)

    cond do
      not Map.get(record, :exists) ->
        npc_say(conn, room_id, npc_name, "如今并无异族联军入侵呀！")

      not Map.get(record, :all_killed) ->
        npc_say(conn, room_id, npc_name, "圣上并未恩准赏赐，尔等速速离去！")

      Map.get(waidi, :born_time) != Map.get(record, :born_time) ->
        npc_say(conn, room_id, npc_name, "你的赏赐已经过期了！")

      character.room_id == @hg_room ->
        npc_say(conn, room_id, npc_name, "你快快向皇上领赏吧！")

      true ->
        yuqian_escort(conn, data, npc_name, room_id, asker_name)
    end
  end

  # yuqian1.c:83-96：say×2 → vision → 双 move → say → vision → 侍卫回原房 → vision
  defp yuqian_escort(conn, data, npc_name, room_id, asker_name) do
    conn
    |> npc_say(room_id, npc_name, "啊，原来是抗击异族联军的义士，快请快请！")
    |> npc_say(room_id, npc_name, "在下这便带你入宫面见圣上！")
    |> escort_vision(room_id, asker_name, "\n{npc}大步地走进皇宫大殿，{name}紧随其后。\n\n")
    |> Teleport.teleport(@hg_room)
    |> npc_goto(data, @hg_room)
    |> npc_say(@hg_room, npc_name, "好了，我带你到大殿了，你可以面见圣上领赏了。")
    |> escort_vision(@hg_room, asker_name, "{npc}头也不回地离去了。\n")
    |> npc_goto(data, room_id)
    |> escort_vision(room_id, asker_name, "{npc}急匆匆的走了过来。\n")
    |> prompt_quiet()
  end

  defp escort_vision(conn, room_id, asker_name, template) do
    if is_binary(room_id) do
      message = String.replace(template, "{name}", asker_name)
      RoomHelpers.broadcast_vision(conn, room_id, message)
    else
      conn
    end
  end

  # set_waidi_word：只写 word/npc 上下文，保留 born_time/number。
  # word/npc_name/npc_room_id 对应 LPC do_answer 在康熙对象上执行时的
  # 免费上下文（ex 殿试路径在玩家进程，需出题时落进 waidi）。
  defp set_waidi_word(conn, character, word, npc_name, room_id) do
    env = character.meta.env || %{}
    waidi = Map.get(env, :waidi) || %{}
    waidi = Map.put(waidi, :word, word)
    waidi = Map.put(waidi, :npc_name, npc_name)
    waidi = Map.put(waidi, :npc_room_id, room_id)
    env = Map.put(env, :waidi, waidi)
    character = %{character | meta: Map.put(character.meta, :env, env)}
    Records.save(character)
    put_character(conn, character)
  end

  # LPC write(bitmap_font(word, 16) + "\n")：谜面仅问询者可见
  defp reply_bitmap(conn, word) do
    conn
    |> render(CommandView, "text", %{text: BitmapFont.render(word, 16) <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 共用 ----

  # LPC command("say ...")：房间广播
  defp npc_say(conn, room_id, npc_name, text) when is_binary(room_id) do
    Helpers.say(conn, room_id, npc_name, text)
  end

  defp npc_say(conn, _room_id, _npc_name, _text), do: conn

  defp prompt_quiet(conn) do
    prompt(conn, CommandView, "prompt", %{})
  end

  defp waidi_of(character) do
    env = character.meta.env || %{}
    Map.get(env, :waidi) || %{}
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
