defmodule Kantele.Character.SmashEvent do
  @moduledoc """
  雷劈事件处理：收到 `character/smitten` 的玩家在自己进程内结算死亡。

  对应 LPC `cmds/arch/smash.c` 的
  `ob->set_temp("die_reason", ...) -> ob->receive_damage("qi", 1, me) -> ob->die()`。
  由于 `Damage.die/2` 只能作用于本进程持有的 character struct，施法者通过
  `smash/strike` 房间事件找到目标后转发本事件，让目标进程自己执行死亡结算。

  - `character/smitten`：写 `die_reason`、扣 1 点气血、调用 `Damage.die/1`、
    落盘并给出雷劈提示。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Feature.Damage

  def smitten(conn, %{data: data} = _event) do
    smiter_name = data[:smiter_name] || "某人"
    die_reason = data[:die_reason] || "被#{smiter_name}用雷劈死了"
    character = current(conn) |> ensure_death_state()

    character =
      character
      |> put_temp("die_reason", die_reason)
      |> receive_damage()
      |> die()

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{
      text: "一道闪电从天而降击中了你，你被#{smiter_name}用雷劈死了。\n"
    })
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  # 兼容非 map data（不崩）
  def smitten(conn, _event), do: smitten(conn, %{data: %{}})

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  # R24 教训：`PlayerMeta` 的 `:combat` 无默认值（nil），`Damage.die/1` 内的
  # `busy?/1` 解构 `meta.combat` 会 FunctionClauseError、`ghost?/1` 对 nil
  # 调 Map.get 会 BadMapError，导致玩家进程退出掉线。进死亡流程前统一兜底。
  defp ensure_death_state(character) do
    meta =
      character.meta
      |> Map.put(:combat, Map.get(character.meta, :combat) || %Combat{})
      |> Map.put(:damage, Map.get(character.meta, :damage) || %{})

    %{character | meta: meta}
  end

  defp put_temp(character, key, value) do
    %{character | meta: PlayerMeta.put_temp(character.meta, key, value)}
  end

  # LPC `ob->receive_damage("qi", 1, me)`。不传 killer：本端口
  # `update_last_damage/2` 对非 nil killer 会调 `character.name(who)`
  # （把 name 字段当函数调用会崩），而 smash 的 1 点气血仅为触发死亡前奏，
  # 死亡结算本身会把 qi 置 1，故省略 killer 不影响结果。
  defp receive_damage(character) do
    case Damage.receive_damage(character, :qi, 1) do
      {:ok, updated} -> updated
      _ -> character
    end
  end

  defp die(character) do
    case Damage.die(character) do
      {:ok, updated} -> updated
      _ -> character
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
