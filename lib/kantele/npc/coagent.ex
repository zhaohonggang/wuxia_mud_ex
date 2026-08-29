defmodule Kantele.Npc.Coagent do
  @moduledoc """
  帮手 NPC（对应 `feature/coagent.c`）

  - `is_coagent?/1`: 帮手识别
  - `is_helping?/1`: 是否已在助战
  - `start_help/3`: 决定是否出动帮忙。返回 `{:noop}` / `{:move, env_id, target_id}`
    指示宿主移动并加入对 target 的击杀。
  - `finish_help/2`: 助战结束回 startroom。返回 `{:stay}` | `{:return, startroom}`

  纯逻辑：消息/移动/击杀副作用由宿主执行。
  """

  @doc "是否帮手"
  def is_coagent?(_self), do: true

  @doc "是否已在助战 (LPC: is_helping)"
  def is_helping?(helping), do: helping == true

  @doc """
  start_help（LPC: start_help(env, helper, ob)）

  - 我已在目标房间且已在杀该目标 -> `{:already}`
  - 我离目标房间远，且没在助战/没在战斗 -> `{:move, env_id, target_id}`
  - 否则 -> `{:noop}`
  """
  def start_help(opts) do
    %{
      in_target_room?: in_room,
      already_killing?: killing,
      helping?: helping,
      fighting?: fighting,
      target_room: target_room,
      target_id: target_id,
      living?: living
    } = opts

    cond do
      not living -> {:noop}

      in_room ->
        if killing, do: {:already}, else: {:fight, target_id}

      helping or fighting ->
        {:noop}

      true ->
        {:move, target_room, target_id}
    end
  end

  @doc "finish_help：助战结束返回 startroom（LPC 语义）"
  def finish_help(startroom, current_room) do
    if startroom != nil and startroom != "" and current_room != startroom do
      {:return, startroom}
    else
      {:stay}
    end
  end
end
