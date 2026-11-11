defmodule Kantele.Character.PossessCommand do
  @moduledoc """
  附身命令：`possess [<目标> | -r | --release]`

  对应 LPC `cmds/arch/possess.c` 的「巫师附身生物」核心语义。本端口无 LPC 的
  body-swap / 会话重绑原语，故实现为**可使用的标记式附身**：

  - `possess <目标>`：附身房间内的一个活物（NPC/玩家），把附身关系记录到
    `Kantele.World.Possession`，并向房间广播「$N化成一道光芒，钻进了$n的体内。」
  - `possess -r` / `possess --release`：解除当前附身。
  - `possess`（无参）：查看当前附身状态。

  仅巫师可用。目标不存在 / 非活物 / 已被附身 / 附身自己 时给出明确提示。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.BeastTaming
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch
  alias Kantele.Combat.Messages
  alias Kantele.World.Possession
  alias Kantele.World.Room

  def run(conn, params) do
    WizArch.guard(conn, params, &handle/2)
  end

  defp handle(conn, %{"rest" => rest}) do
    arg = String.trim(rest)

    cond do
      arg == "" ->
        show_status(conn)

      arg in ["-r", "--release", "release"] ->
        release_possession(conn)

      true ->
        possess_target(conn, arg)
    end
  end

  defp handle(conn, _params), do: show_status(conn)

  # --- 查看状态 ---
  defp show_status(conn) do
    case Possession.target_of(conn.character.id) do
      nil ->
        reply(conn, "你当前没有附身任何对象。\n")

      %{target_name: name} ->
        reply(conn, "你当前附身于：#{name}\n")
    end
  end

  # --- 解除附身 ---
  defp release_possession(conn) do
    case Possession.release_by_possessor(conn.character.id) do
      :ok ->
        reply(conn, "你已解除附身。\n")

      {:error, :not_found} ->
        reply(conn, "你当前没有附身任何对象。\n")
    end
  end

  # --- 附身目标 ---
  defp possess_target(conn, arg) do
    me = conn.character

    case BeastTaming.find(conn, arg) do
      nil ->
        reply(conn, "这里没有名字叫 #{arg} 的活物。\n")

      target ->
        cond do
          target.id == me.id ->
            reply(conn, "你不能附身自己。\n")

          not BeastTaming.living?(target) ->
            reply(conn, "#{target.name} 已经死了，无法附身。\n")

          Possession.possessed?(target.id) ->
            reply(conn, "#{target.name} 已经被附身了。\n")

          true ->
            do_possess(conn, me, target)
        end
    end
  end

  defp do_possess(conn, me, target) do
    :ok = Possession.possess(me.id, target.id, target.name)

    vision =
      Messages.interpolate("$N化成一道光芒，钻进了$n的体内。", %{
        n1: me.name,
        n2: target.name
      })

    broadcast(conn, vision)

    reply(conn, "你附身到了#{target.name}的身上。\n")
  end

  # --- 房间广播（与 BeastTaming 同款注入点，便于测试）---
  defp broadcast(conn, text) do
    room_id = conn.character.room_id
    except_pid = conn.character.pid

    case Map.get(conn.private || %{}, :possess_broadcast) do
      fun when is_function(fun, 2) -> fun.(room_id, text)
      _ -> safe_tell_room(room_id, text, except_pid)
    end

    :ok
  end

  defp safe_tell_room(room_id, text, except_pid) do
    Room.tell_room(%Room{id: room_id}, text, except_pid)
  rescue
    _ -> :ok
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
