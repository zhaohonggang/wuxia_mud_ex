defmodule Kantele.Character.UltraEvent do
  @moduledoc """
  大宗师评价的跨进程回执（`kungfu/class/ultra/ultra.h` 的 call_out 链）。

  NPC 侧：`ultra/accept-fight` 记 `temp["opinion"]=玩家 id`，起 2 拍
  `check_opinion/3`；玩家侧：`ultra/fight-result` 清 want_opinion + 内力清零，
  `ultra/rank-result` 落评级/大宗师标志与逐字文案。

  评级纯函数全部在 `Kantele.NPC.Ultra`，本模块只做进程间搬运与落库。
  """

  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.NPC.Ultra
  alias Kantele.World.NpcActions.CallOut

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]
  alias Kantele.Character.CommandView

  # ---- NPC 侧 ----

  @doc "LPC `accept_fight` 通过分支：set_temp(\"opinion\", me) + call_out(check_opinion, 2, me)。"
  def accept_fight(conn, %{data: %{player: player, ultra: cfg}}) when is_map(player) do
    npc = conn.character
    temp = Map.put(npc.meta.temp || %{}, "opinion", player.id)
    npc = %{npc | meta: %{npc.meta | temp: temp}}
    conn = put_character(conn, npc)

    CallOut.schedule(conn.character, __MODULE__, :check_opinion, 2, [player, cfg])

    notify(player, "ultra/fight-result", %{
      want_key: Map.get(cfg, :want_key, Map.get(cfg, :category, "")),
      neili_zero: true
    })

    conn
  end

  def accept_fight(conn, _event), do: conn

  @doc "LPC `call_out(\"check_opinion\", 2, me)`：到期后评级，结果回投玩家进程。"
  def check_opinion(conn, player, cfg) do
    npc = conn.character
    temp = Map.delete(npc.meta.temp || %{}, "opinion")
    conn = put_character(conn, %{npc | meta: %{npc.meta | temp: temp}})

    {updated, message} = Ultra.check_opinion(player, npc, cfg)

    notify(player, "ultra/rank-result", %{
      character: updated,
      message: message
    })

    conn
  end

  def check_opinion(conn, _player, _cfg), do: conn

  # ---- 玩家侧 ----

  @doc "一招试招后：LPC me->delete_temp(\"want_opinion\") + me->set(\"neili\", 0)。"
  def fight_result(conn, %{data: data}) do
    character = conn.character
    meta = character.meta
    key = Map.get(data, :want_key, "")

    meta =
      if key != "" do
        PlayerMeta.delete_temp(meta, "want_opinion/#{key}")
      else
        meta
      end

    meta =
      if Map.get(data, :neili_zero) do
        vitals = %{meta.vitals | neili: 0}
        %{meta | vitals: vitals}
      else
        meta
      end

    put_character(conn, %{character | meta: meta})
  end

  def fight_result(conn, _event), do: conn

  # NPC 的 init()（`kungfu/class/ultra/*.c`）：me->delete_temp("want_opinion")。
  # ex 把 want_opinion/<key> 存成平铺 temp 键，这里整组清掉（不只清单个 want_key）。
  @doc "清掉全部 want_opinion/<key> 意图（大宗师 init() 的无条件分支）。"
  def clear_intent(conn, %{data: %{clear_want_opinion: true}}) do
    character = conn.character
    meta = character.meta
    temp = if is_map(meta.temp), do: meta.temp, else: %{}

    temp =
      Enum.reduce(temp, %{}, fn {key, value}, acc ->
        if is_binary(key) and String.starts_with?(key, "want_opinion/") do
          acc
        else
          Map.put(acc, key, value)
        end
      end)

    put_character(conn, %{character | meta: %{meta | temp: temp}})
  end

  def clear_intent(conn, _event), do: conn

  @doc "评级结果：落玩家 meta.env/combat 更新并显示大宗师逐字文案。"
  def rank_result(conn, %{data: %{character: updated, message: message}}) when is_map(updated) do
    conn =
      put_character(conn, updated)
      |> render(CommandView, "text", %{text: to_string(message)})
      |> prompt(CommandView, "prompt", %{})

    conn
  end

  def rank_result(conn, _event), do: conn

  # ---- 工具 ----

  defp notify(%{pid: pid}, topic, data) when is_pid(pid) do
    send(pid, %Event{from_pid: self(), topic: "ultra/#{topic}", data: data})
  end

  defp notify(_, _, _), do: :ok
end
