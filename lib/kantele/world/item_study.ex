defmodule Kantele.World.ItemStudy do
  @moduledoc """
  逐物品自定义 `study` 行为（LPC `init()` 里 `add_action("do_study", "study")` 的忠实移植）。

  大多数秘籍走通用流程（物品 `meta.book` + `StudyCommand`），但少数物品在
  `init()` 里挂了**自己的** `do_study`，语义与通用流程不同（门槛、消耗、文案都不同），
  必须按物品 id 派发：

  - `kunlun:items.lyj_book`（`d/kunlun/obj/lyj-book.c`）：正两仪剑心得，只对
    100 < 两仪剑法 <= 180 的玩家有效，扣 40 精。
  - `lingxiao:items.book_iron`（`d/lingxiao/obj/book-iron.c`）：铁手掌，
    **必须在战斗中**且 30 <= 招架 <= 100 才有效，扣 20 精。

  `study/4` 返回 `{:done, conn}`（已处理，命令结束）或 `:fallback`（交回通用流程）。

  ## 与 LPC 的差异

  LPC `improve_skill(skill, amount, 1)` 走「learned 点数累积到 (lvl+1)^2 才升级」的曲线，
  本项目 `Kantele.Character.Stats.improve_skill/2` 统一简化为「等级 +1」（全库秘籍同款，
  见 `StudyCommand.execute_study/4`）。此处沿用同一简化，不单为两本书另造一套曲线。
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.RoomActions.Helpers

  import Kalevala.Character.Conn

  @doc "按物品定义 id 派发自定义研读；无自定义行为返回 `:fallback`。"
  def study(conn, book_instance, arg, character) do
    # 派发键是**物品定义** id（实例 id 形如 "inst-..."，且书册可能挂随机标题副本）
    item = Kantele.World.Item.instance_item(book_instance)

    case handler(Map.get(item, :id)) do
      nil -> :fallback
      fun -> fun.(conn, arg, character)
    end
  end

  defp handler("kunlun:items.lyj_book"), do: &__MODULE__.LiangyiXinde.study/3
  defp handler("lingxiao:items.book_iron"), do: &__MODULE__.IronHand.study/3
  defp handler(_), do: nil

  defmodule LiangyiXinde do
    @moduledoc "`d/kunlun/obj/lyj-book.c` `do_study`：正两仪剑心得。"
    @skills ~w(shu book xinde)

    def study(conn, arg, character) do
      skill = Stats.skill(character.meta.stats, "liangyi-jian")

      cond do
        String.trim(arg) not in @skills ->
          fail(conn, "你要学什么？\n")

        character.meta.vitals.jing < 30 ->
          fail(conn, "你太累了，还是歇会再研究吧！\n")

        skill > 100 and skill <= 180 ->
          do_study(conn, character)

        true ->
          # LPC 两条分支都 return 1（无提示、无消耗），命令静默结束
          {:done, conn}
      end
    end

    defp do_study(conn, character) do
      stats = character.meta.stats
      vitals = %{character.meta.vitals | jing: character.meta.vitals.jing - 40}

      gain = div(stats.int, 2) + div(Stats.skill(stats, "literate"), 5)
      stats = apply_gain(stats, gain)

      character = %{character | meta: %{character.meta | stats: stats, vitals: vitals}}
      Records.save(character)

      conn
      |> put_character(character)
      |> Helpers.broadcast_vision(character.room_id, "$N苦心研究「两仪剑心得」，思索良久，似乎有所领悟。")
      |> finish()
    end

    # 简化模型：每次研读升 1 级（与 StudyCommand 一致）
    defp apply_gain(stats, _gain) do
      {stats, _} = Stats.improve_skill(stats, "liangyi-jian")
      stats
    end

    defp fail(conn, text) do
      {:done,
       conn
       |> render(CommandView, "text", %{text: text})
       |> prompt(CommandView, "prompt", %{})}
    end

    defp finish(conn) do
      {:done, prompt(conn, CommandView, "prompt", %{})}
    end
  end

  defmodule IronHand do
    @moduledoc """
    `d/lingxiao/obj/book-iron.c` `do_study`：铁手掌（易筋经攻防篇）。
    **只在战斗中**生效 —— 所以 `StudyCommand` 的「战斗中不能研读」守卫对本书不适用。
    """
    @skills ["iron hand", "hand"]

    def study(conn, arg, character) do
      skill = Stats.skill(character.meta.stats, "parry")

      cond do
        String.trim(arg) not in @skills ->
          fail(conn, "你要学什么？\n")

        fighting?(character) and skill >= 30 and skill <= 100 ->
          do_study(conn, character)

        true ->
          # LPC `return 0` = 未处理，落到全局 study —— 而全局 study 在战斗中会被拒绝，
          # 净效果就是「没反应」。这里直接静默结束。
          {:done, conn}
      end
    end

    defp do_study(conn, character) do
      stats = character.meta.stats
      vitals = %{character.meta.vitals | jing: character.meta.vitals.jing - 20}
      stats = apply_gain(stats, stats.int)

      character = %{character | meta: %{character.meta | stats: stats, vitals: vitals}}
      Records.save(character)

      conn
      |> put_character(character)
      |> Helpers.broadcast_vision(
        character.room_id,
        "$N一边战斗，一边抽空急急忙忙地拿出铁手掌仔细研究。"
      )
      |> prompt(CommandView, "prompt", %{})
      |> then(&{:done, &1})
    end

    defp apply_gain(stats, _gain) do
      {stats, _} = Stats.improve_skill(stats, "parry")
      stats
    end

    defp fighting?(character) do
      Kantele.Character.Combat.fighting?(character.meta.combat)
    end

    defp fail(conn, text) do
      {:done,
       conn
       |> render(CommandView, "text", %{text: text})
       |> prompt(CommandView, "prompt", %{})}
    end
  end
end
