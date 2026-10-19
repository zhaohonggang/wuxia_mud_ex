defmodule Kantele.World.ItemActions.Play do
  @moduledoc """
  乐器 `play` 动作（第十二批，物品动作通道）。

  对应 LPC `inherit/misc/_qin.c` / `_xiao.c` / `_zheng.c`：

      int play_qin(string arg) {
              string my_id;
              if (arg && sscanf(arg, "%s with %s", arg, my_id) == 2 &&
                  ! this_object()->id(my_id))
                      return 0;
              return SKILL_D("tanqin-jifa")->play(this_player(), this_object(), arg);
      }

  `inherit/misc/_qin.c` 的 `play_qin` 被 19 个乐器、`_xiao.c` 的 `play_xiao`
  被 5 个、`_zheng.c` 的 `play_zheng` 被 2 个 inherit（见
  `scripts/backfill_item_actions.py` 的 TARGETS）。三者逐字同构，只是委托的
  skill 不同：琴→`tanqin-jifa`、箫→`chuixiao-jifa`、筝→`guzheng-jifa`
  （差异在 `kungfu/skill/*-jifa.c` 的 `play()` 文案）。

  本模块注册三份 handler 名（`ItemActionHandlers`），按 `params.handler`
  分派 jifa；守门 / 分级文案 / `start_busy` 逐字对 LPC。

  ## 语义（LPC `*-jifa.c` 的 `play()`，按检查序）

  1. `arg` 为空 → notify_fail「你要弹什么曲子？」（各 jifa 措辞不同）
  2. `query_skill(arg)` 为 0 → 「你不会弹这首曲子。」（曲目技能）
  3. `SKILL_D(arg)->valid_enable(jifa)` 为假 → 「这不能用来弹奏。」
  4. `is_busy()` → 「你现在正忙，等会儿再弹琴吧。」
  5. `lvl = query_skill(arg) + query_skill(jifa) / 2`，按 lvl 分 7 档
     `message_vision`（阈值 15/30/60/90/150/225/300）
  6. `start_busy(3 + random(3))`
  7. `SKILL_D(arg)->do_effect(me)` —— 曲目技能效果。Kantele 侧歌谱技能
     （bihai-chaosheng 等）是 P9 骨架（无 do_effect 实现、且未进 Skills
     注册表），故此处经 `Skills.get(arg)` + `function_exported?(:do_effect, 2)`
     守卫：**技能未登记或没导出 do_effect 时为空操作**（只播文案 + 忙乱，
     与 LPC 技能缺省时一致）；P9 把歌谱技能迁移为真实实现后自动接通，
     本通道无需改动。守卫钩子见 `maybe_do_effect/3`。

  ## `<song> with <id>` 语义

  LPC `sscanf(arg, "%s with %s", arg, my_id)`：玩家显式指定乐器 id 时，
  id 不匹配本对象的乐器**返回 0**（`return 0` → 分发器尝试下一个候选
  物品，见 `ItemActionDispatcher`）。匹配时 `arg` 收窄为 `with` 前的曲名。

  ## 歌谱名 / valid_enable 表

  LPC `to_chinese(arg)` 查 CHINESE_D 的 e2c 词典（编译态 `.o`，不可读），
  曲名按各技能源文件的文案（`kungfu/skill/*.c` 的 notify_fail / 头部
  注释）逐字录入 `@song_names`；`valid_enable` 按各技能源文件的
  `valid_enable()` 逐字录入 `@song_enables`。未录入曲名回落为技能 id
  （LPC 词典未收录时同样回落 key）。
  """
  use Kantele.World.ItemAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills
  alias Kantele.World.Item
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  # handler 名（LPC `add_action` 第一个参数）→ jifa 技能 id
  @jifas %{
    "play_qin" => "tanqin-jifa",
    "play_xiao" => "chuixiao-jifa",
    "play_zheng" => "guzheng-jifa"
  }

  # 曲目 id → 中文曲名（源见 moduledoc）
  @song_names %{
    "bihai-chaosheng" => "碧海潮生曲",
    "qingxin-pushan" => "清心普善咒",
    "xiaoao-jianghu" => "笑傲江湖曲",
    "guangling-san" => "广陵散",
    "jian-jia" => "蒹葭",
    "qiuyue-lai" => "秋月籁",
    "tieqin-yin" => "铁琴音",
    "xiaoxiang-yeyu" => "潇湘夜雨",
    "taohua-yuan" => "桃花怨",
    "chinese-anthem" => "义勇军进行曲",
    "wushe-qu" => "舞蛇曲",
    "xiyu-tiezheng" => "西域铁筝音",
    "qixian-wuxingjian" => "七弦无形剑"
  }

  # 曲目 id → 可 enable 的 jifa 列表（源见 moduledoc）
  @song_enables %{
    "bihai-chaosheng" => ~w(chuixiao-jifa),
    "qingxin-pushan" => ~w(tanqin-jifa),
    "xiaoao-jianghu" => ~w(chuixiao-jifa tanqin-jifa),
    "guangling-san" => ~w(tanqin-jifa),
    "jian-jia" => ~w(tanqin-jifa),
    "qiuyue-lai" => ~w(tanqin-jifa),
    "tieqin-yin" => ~w(tanqin-jifa),
    "xiaoxiang-yeyu" => ~w(tanqin-jifa),
    "taohua-yuan" => ~w(chuixiao-jifa),
    "chinese-anthem" => ~w(chuixiao-jifa tanqin-jifa guzheng-jifa),
    "wushe-qu" => ~w(guzheng-jifa),
    "xiyu-tiezheng" => ~w(guzheng-jifa),
    "qixian-wuxingjian" => ~w(unarmed parry sword tanqin-jifa)
  }

  @doc false
  def song_names, do: @song_names

  @impl true
  def run(conn, %{handler: handler, trailing: trailing, item: item}) do
    case Map.fetch(@jifas, handler) do
      {:ok, jifa} -> do_run(conn, conn.character, item, jifa, trailing)
      :error -> :not_handled
    end
  end

  defp do_run(conn, character, item, jifa, trailing) do
    case split_with(trailing, item) do
      :not_handled ->
        # LPC return 0：`<song> with <id>` 的 id 不是本对象
        :not_handled

      {:ok, arg} ->
        play(conn, character, item, jifa, arg)
    end
  end

  # LPC `sscanf(arg, "%s with %s", arg, my_id) == 2 && !id(my_id)` → return 0。
  # 无 " with " 或 id 匹配 → arg 原样（匹配时收窄为 with 前的词）。
  defp split_with("", _item), do: {:ok, ""}

  defp split_with(arg, item) do
    case Regex.run(~r/^(\S+)\s+with\s+(\S+)/, arg) do
      [_, song, target] ->
        if Item.matches?(item, target), do: {:ok, song}, else: :not_handled

      nil ->
        {:ok, arg}
    end
  end

  defp play(conn, character, item, jifa, arg) do
    stats = character.meta.stats
    song_level = Stats.skill(stats, arg)
    jifa_level = Stats.skill(stats, jifa)

    cond do
      arg == "" ->
        render(conn, guard_text(jifa, :no_arg))

      song_level == 0 ->
        render(conn, guard_text(jifa, :unknown_song))

      not valid_enable?(arg, jifa) ->
        render(conn, guard_text(jifa, :invalid))

      busy?(character) ->
        render(conn, guard_text(jifa, :busy))

      true ->
        # LPC: lvl += query_skill(jifa) / 2（整数除）
        lvl = song_level + div(jifa_level, 2)
        do_play(conn, character, item, jifa, arg, lvl)
    end
  end

  defp valid_enable?(song, jifa) do
    case Map.fetch(@song_enables, song) do
      {:ok, enables} -> jifa in enables
      # LPC 未收录曲名时 SKILL_D 返回 0，query_skill 已先行拦下，不会到这
      :error -> false
    end
  end

  defp do_play(conn, character, item, jifa, arg, lvl) do
    m_name = Map.get(@song_names, arg, arg)
    template = tier_text(jifa, lvl, m_name)

    conn =
      conn
      |> broadcast(item, template)
      |> start_busy(character, 3 + :rand.uniform(3))
      # LPC: SKILL_D(arg)->do_effect(me) —— 曲目技能效果。
      # 守卫：歌谱技能未登记（Skills.get 返回 nil）或未导出 do_effect/2 时
      # 为空操作；P9 迁移后真实实现自动接通（见 maybe_do_effect/3）。
      |> maybe_do_effect(character, arg)

    conn
  end

  # LPC `SKILL_D(arg)->do_effect(me)`：曲名 arg 即歌谱技能 id。
  # 仅当技能已登记且导出 do_effect/2 才调用；否则原样返回 conn（空操作）。
  defp maybe_do_effect(conn, character, song) do
    case Skills.get(song) do
      module when is_atom(module) ->
        if :erlang.function_exported(module, :do_effect, 2) do
          module.do_effect(conn, character)
        else
          conn
        end

      _ ->
        conn
    end
  end

  # LPC message_vision(msg, me, ob)：$N=行动者（玩家）、$n=乐器。
  # $N 交给 broadcast_vision 归一化为 {npc}（VisionView 按接收者渲染「你」/
  # 姓名）；$n 与观看者无关，在此替换为乐器名（同 wield_command 的 {name}）。
  defp broadcast(conn, item, template) do
    text = String.replace(template, "$n", item.name)

    case room_id(conn) do
      room_id when is_binary(room_id) and room_id != "" ->
        RoomHelpers.broadcast_vision(conn, room_id, text)

      _ ->
        # 无房间上下文（异常路径）：降级为只给自己看，不崩
        render(conn, text)
    end
  end

  defp start_busy(conn, character, rounds) do
    combat = character.meta.combat || Combat.new()
    combat = Combat.start_busy(combat, rounds)
    put_character(conn, %{character | meta: %{character.meta | combat: combat}})
  end

  defp busy?(character) do
    case character.meta.combat do
      %Combat{} = combat -> Combat.busy?(combat)
      _ -> false
    end
  end

  defp room_id(conn) do
    case Map.get(conn, :character) do
      %{room_id: room_id} when is_binary(room_id) -> room_id
      _ -> nil
    end
  end

  defp render(conn, text), do: RoomHelpers.render_to_player(conn, text)

  # 守门文案：逐字对 kungfu/skill/{tanqin,chuixiao,guzheng}-jifa.c 的 notify_fail。
  # 琴与筝的 7 档分级文案逐字相同（都是「弹」），仅守门措辞不同。
  defp guard_text("tanqin-jifa", :no_arg), do: "你要弹什么曲子？\n"
  defp guard_text("tanqin-jifa", :unknown_song), do: "你不会弹这首曲子。\n"
  defp guard_text("tanqin-jifa", :invalid), do: "这不能用来弹奏。\n"
  defp guard_text("tanqin-jifa", :busy), do: "你现在正忙，等会儿再弹琴吧。\n"

  defp guard_text("chuixiao-jifa", :no_arg), do: "你要吹什么曲子？\n"
  defp guard_text("chuixiao-jifa", :unknown_song), do: "你不会吹这首曲子。\n"
  defp guard_text("chuixiao-jifa", :invalid), do: "这也能当箫曲吹么？\n"
  defp guard_text("chuixiao-jifa", :busy), do: "你现在正忙，等会儿再吹箫吧。\n"

  defp guard_text("guzheng-jifa", :no_arg), do: "你要演奏什么曲子？\n"
  defp guard_text("guzheng-jifa", :unknown_song), do: "你不会演奏这首曲子。\n"
  defp guard_text("guzheng-jifa", :invalid), do: "这不能用来弹奏！\n"
  defp guard_text("guzheng-jifa", :busy), do: "你现在正忙，等会儿再演奏吧。\n"

  # 7 档分级文案（阈值 15/30/60/90/150/225/300），逐字对 LPC message_vision。
  defp tier_text("tanqin-jifa", lvl, m) when lvl < 15,
    do: "\n$N胡乱拨了拨$n，结果只是发出了几下刺耳的杂音。\n"

  defp tier_text("tanqin-jifa", lvl, _m) when lvl < 30,
    do: "\n$N拨拉了一下$n，发出几声怪响，难听的一塌糊涂。\n"

  defp tier_text("tanqin-jifa", lvl, _m) when lvl < 60,
    do: "\n$N摆好$n轻轻弹了几下，声音还算清脆，不太难听。\n"

  defp tier_text("tanqin-jifa", lvl, m) when lvl < 90,
    do: "\n$N摆好$n弹了一首#{m}，韵律洋洋洒洒，颇为不错。\n"

  defp tier_text("tanqin-jifa", lvl, m) when lvl < 150,
    do: "\n$N摆好$n弹了一首#{m}，颇为动人，引人入胜。\n"

  defp tier_text("tanqin-jifa", lvl, m) when lvl < 225,
    do: "\n$N摆好$n弹了一首#{m}，听得众人感慨万千，甚是投入。\n"

  defp tier_text("tanqin-jifa", lvl, m) when lvl < 300,
    do: "\n$N摆好$n弹了一首#{m}，琴音宛若溪水荡流，怡然陶趣，雅致万千。\n"

  defp tier_text("tanqin-jifa", _lvl, m),
    do: "\n$N摆好$n弹了一首#{m}，宛若清溪流上心头，令人无酒自醉，却又似身至仙境，心灵空明。\n"

  defp tier_text("chuixiao-jifa", lvl, _m) when lvl < 15,
    do: "\n$N鼓足气吹了一下$n，结果只是发出几下刺耳的呜呜声。\n"

  defp tier_text("chuixiao-jifa", lvl, _m) when lvl < 30,
    do: "\n$N鼓足气吹了一下$n，发出几声怪响，难听的一塌糊涂。\n"

  defp tier_text("chuixiao-jifa", lvl, _m) when lvl < 60,
    do: "\n$N拿起$n轻轻吹了几声，声音还算马马虎虎，不太难听。\n"

  defp tier_text("chuixiao-jifa", lvl, m) when lvl < 90,
    do: "\n$N拿起$n吹了一首#{m}，韵律洋洋洒洒，颇为不错。\n"

  defp tier_text("chuixiao-jifa", lvl, m) when lvl < 150,
    do: "\n$N拿起$n吹了一首#{m}，颇为动人，引人入胜。\n"

  defp tier_text("chuixiao-jifa", lvl, m) when lvl < 225,
    do: "\n$N拿起$n吹了一首#{m}，听得众人感慨万千，甚是投入。\n"

  defp tier_text("chuixiao-jifa", lvl, m) when lvl < 300,
    do: "\n$N拿起$n吹了一首#{m}，箫音如梦如幻，似乎有一股清香直沁心脾。\n"

  defp tier_text("chuixiao-jifa", _lvl, m),
    do: "\n$N拿起$n吹了一首#{m}，若哀若思，犹如身临其境，忽悲忽喜，又如乘风而行，不知踪影。\n"
end
