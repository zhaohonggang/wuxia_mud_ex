defmodule Kantele.World.RoomActions.Huashan.Chaoyang do
  @moduledoc """
  P5-9 #9 一次性场景：华山朝阳峰「拉青藤 / 跳崖」（房间层）。

  忠实移植自 `d/huashan/chaoyang.c` 的 `do_la` 与 `do_jump`，注册
  `huashan:chaoyang`（UCL 已由转换器写出 `actions = { la = "do_la", jump = "do_jump" }`
  与 `item_desc = { ya, teng }`，**零 UCL 改动**）。

  ## LPC 源（已回源核对）

      int do_la(string arg)
      {
              object me = this_player();
              if (! arg || arg != "teng")  return notify_fail("你要拉什么？\\n");
              if (me->is_busy() || me->is_fighting())
                      return notify_fail("等你忙完了再说吧！\\n");
              if (me->query_temp("la_teng_huashan"))
                      return notify_fail("你已经拉住青藤了。\\n");
              message_vision(HIG "$N" HIG "将青藤牢牢地抓住了。\\n", me);
              me->set_temp("la_teng_huashan", 1);
              me->start_busy(2);
              return 1;
      }

      int do_jump(string arg)
      {
              object me = this_player();
              if (! arg || arg != "ya")  return notify_fail("你要往哪儿跳？\\n");
              if (me->is_busy() || me->is_fighting())
                      return notify_fail("等你忙完了再说吧！\\n");
              if (! me->query_temp("la_teng_huashan") && me->query_dex()<30)
              {
                      message_vision(HIM "$N" HIM "纵身跳下悬崖 ……\\n", me);
                      me->move("/d/huashan/xuanya");
                      me->set_temp("die_reason", "跳下华山悬崖，自杀身亡");
                      me->die();
                      return 1;
              }
              message_vision(HIG "$N" HIG "拉着青藤跳下悬崖……\\n", me);
              tell_object(me, HIG "猛然间，你发现下面有一个小洞，你猛一弯腰，借力跳了进去。\\n" NOR);
              me->move("/d/huashan/jinshedong");
              me->delete_temp("la_teng_huashan");
              me->start_busy(2);
              return 1;
      }

  ## 移植要点

  - `query_temp("la_teng_huashan")` → `meta.temp["la_teng_huashan"]`。房间动作侧
    `Helpers` **没有** `temp/2`（那是 NPC 侧 API），直读/直写 `meta.temp`
    （同 `City.Qiyuan` 的座位处理）。
  - `is_busy()` / `start_busy(n)` 与 `RoomActions.MoveStone` 的原语语义一致
    （`meta.combat.busy`，由 combat tick 逐轮递减）；本模块内联同一实现而非直接
    调用，因为 `PlayerMeta` 的 `:combat` **无默认值（nil）**，`Combat.busy?(nil)`
    会 FunctionClauseError，必须统一 `|| %Combat{}` 兜底（同 `smith.ex` 的
    `Combat.start_busy(meta.combat || %Combat{}, ...)`）。
  - `is_fighting()` → `Combat.fighting?/1`（`meta.combat.enemies` 非空）。
  - `me->move(...)` → `Helpers.move_to/2`；`me->die()` → `RoomActions.Break.die/1`
    （内部 `Damage.die/1` 死亡结算 + `put_character`），与 P5-6 门/容器批同一原语。
  - `set_temp("die_reason", ...)` 照写：当前引擎**无消费点**（`die_reason` 只出现在
    若干 perform 的注释里），仅作数据留痕，与 LPC 行为不冲突。
  - LPC 的 `HIG`/`HIM`/`NOR` 颜色宏按既有约定剥掉（UCL 的 `item_desc` 同样已剥）。
  - 注意 `message_vision(HIG "$N" HIG "……")` 里的 `$N` 是**独立字符串**，拼接后
    只有**一个** `$N`（不是两个）。
  - `query_dex()<30` 用 `Stats.query_dex/1`（同 `damo_jian/sanjue.ex` 的
    `Stats.query_dex(stats) < 30` 写法，不带装备 applies）。

  ## 已知缺口

  - 跳崖自杀分支的**复活点**由角色自身记录决定（`Damage.die/1` 已含复活安排），
    但 `die_reason` 文案未接进死亡播报（引擎无该消费点），故玩家看不到
    「跳下华山悬崖，自杀身亡」这句死亡原因——与全库其它 `die_reason` 一致。
  """

  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @room "huashan:chaoyang"

  # LPC `me->move("/d/huashan/xuanya")` / `me->move("/d/huashan/jinshedong")`
  @xuanya "huashan:xuanya"
  @jinshedong "huashan:jinshedong"

  # LPC `me->query_dex() < 30`
  @dex_threshold 30

  # LPC `tell_object(me, HIG "猛然间，你发现下面有一个小洞，你猛一弯腰，借力跳了进去。\n" NOR)`
  @hole_text "猛然间，你发现下面有一个小洞，你猛一弯腰，借力跳了进去。\n"

  # ---- 分发 -----------------------------------------------------------------

  @impl true
  def run(%{character: nil}, _params), do: :not_handled

  def run(conn, %{room_id: room_id, verb: verb, trailing: trailing}) when is_binary(room_id) do
    if room_id == @room do
      arg = trailing |> to_string() |> String.trim()

      case verb do
        "do_la" -> do_la(conn, arg)
        "do_jump" -> do_jump(conn, arg)
        _ -> :not_handled
      end
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  # ---- la -------------------------------------------------------------------

  defp do_la(conn, arg) do
    character = current(conn)

    cond do
      arg != "teng" ->
        fail(conn, "你要拉什么？\n")

      busy_or_fighting?(character) ->
        fail(conn, "等你忙完了再说吧！\n")

      la_teng?(character) ->
        fail(conn, "你已经拉住青藤了。\n")

      true ->
        conn
        |> Helpers.broadcast_vision(@room, "$N将青藤牢牢地抓住了。\n")
        |> put_temp("la_teng_huashan", 1)
        |> start_busy(2)
    end
  end

  # ---- jump -----------------------------------------------------------------

  defp do_jump(conn, arg) do
    character = current(conn)

    cond do
      arg != "ya" ->
        fail(conn, "你要往哪儿跳？\n")

      busy_or_fighting?(character) ->
        fail(conn, "等你忙完了再说吧！\n")

      not la_teng?(character) and dex(character) < @dex_threshold ->
        # 没拉青藤且轻功不够：直接摔死
        conn
        |> Helpers.broadcast_vision(@room, "$N纵身跳下悬崖 ……\n")
        |> Helpers.move_to(@xuanya)
        |> put_temp("die_reason", "跳下华山悬崖，自杀身亡")
        |> ensure_death_state()
        |> Break.die()

      true ->
        conn
        |> Helpers.broadcast_vision(@room, "$N拉着青藤跳下悬崖……\n")
        |> Helpers.render_to_player(@hole_text)
        |> Helpers.move_to(@jinshedong)
        |> delete_temp("la_teng_huashan")
        |> start_busy(2)
    end
  end

  # ---- temp（`meta.temp`） --------------------------------------------------

  defp la_teng?(character), do: truthy?(Map.get(temp(character), "la_teng_huashan"))

  defp temp(character), do: (character.meta && character.meta.temp) || %{}

  defp put_temp(conn, key, value) do
    character = current(conn)
    temp = Map.put(temp(character), key, value)
    put_character(conn, %{character | meta: %{character.meta | temp: temp}})
  end

  defp delete_temp(conn, key) do
    character = current(conn)
    temp = Map.delete(temp(character), key)
    put_character(conn, %{character | meta: %{character.meta | temp: temp}})
  end

  # LPC 真值语义：nil / false / 0 / "" 为假
  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_value), do: true

  # ---- 忙 / 战斗 ------------------------------------------------------------

  # LPC `me->query_dex()`（`Stats.query_dex/1` 只收 `%Stats{}`，nil 会
  # FunctionClauseError；无 stats 视为 0，与 LPC 查不到回 0 一致）
  defp dex(character) do
    case character.meta && character.meta.stats do
      %Stats{} = stats -> Stats.query_dex(stats)
      _ -> 0
    end
  end

  defp combat(character), do: character.meta.combat || %Combat{}

  defp busy_or_fighting?(character) do
    c = combat(character)
    Combat.busy?(c) or Combat.fighting?(c)
  end

  # LPC `me->start_busy(n)`
  defp start_busy(conn, rounds) when is_integer(rounds) and rounds > 0 do
    character = current(conn)
    c = Combat.start_busy(combat(character), rounds)
    put_character(conn, %{character | meta: %{character.meta | combat: c}})
  end

  defp fail(conn, text), do: Helpers.render_to_player(conn, text)

  # `Damage.die/1` 内部 `busy?/1` 与 `ghost?/1` 直接解构 `meta.combat` / `meta.damage`：
  # 前者 `Combat.busy?(nil)` 会 FunctionClauseError、后者 `Map.get(nil, ...)` 会
  # BadMapError —— 都会让 cowboy 进程退出、玩家掉线（R24 的教训）。`PlayerMeta`
  # 里 `:combat` **无默认值（nil）**，故进 `die` 前统一兜底；这是健壮性守卫，
  # 不改 LPC 行为（LPC `me->die()` 不查这两项）。
  defp ensure_death_state(conn) do
    character = current(conn)
    meta = character.meta

    meta =
      meta
      |> Map.put(:combat, meta.combat || %Combat{})
      |> Map.put(:damage, meta.damage || %{})

    put_character(conn, %{character | meta: meta})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
