defmodule ExKantele.World.Room.Qianting do
  @moduledoc """
  \u{8FC7}\u{79FB}: \u{5927}\u{95E8} push/close/\u{81EA}\u{52A8}\u{5173}\u{95E8}/valid_leave/\u{52A8}\u{6001} exit
  """

  @gate_states [:close, :open]
  @auto_close_delay 10000
  @zoudao_path "/d/room/panlong/zoudao"
  @laopu_name "\u{8001}\u{4EDF}"

  @push_msgs %{
    owner: "\u{63A8}\u{95E8}\u{6D88}\u{606F}",
    laopu_for_owner: "\u{8001}\u{4EDF}\u{5E2E}\u{4E3B}\u{4EBA}\u{5F00}\u{95E8}",
    laopu_for_permit: "\u{62E6}\u{4F4F} {respect} \u{8BF7}\u{56DE}",
    laopu_opens: "\u{8001}\u{4EDF}\u{5F00}\u{95E8}",
    nobody: "\u{5927}\u{95E8}\u{88AB}\u{6253}\u{5F00}"
  }

  @close_msgs %{
    owner: "\u{4E3B}\u{4EBA}\u{5173}\u{95E8}",
    laopu_for_owner: "\u{8001}\u{4EDF}\u{5E2E}\u{4E3B}\u{4EBA}\u{5173}\u{95E8}",
    owner_self: "\u{81EA}\u{5DF1}\u{5173}\u{95E8}",
    laopu_closes: "\u{8001}\u{4EDF}\u{5173}\u{95E8}",
    nobody: "\u{5927}\u{95E8}\u{88AB}\u{5173}\u{4E0A}"
  }

  @broadcast_push "\u{5927}\u{95E8}\u{88AB}\u{63A8}\u{5F00}"
  @broadcast_close "\u{5927}\u{95E8}\u{88AB}\u{5173}\u{4E0A}"

  @valid_leave_msgs %{
    owner: "\u{8BF7}\u{8FDB}",
    permit: "\u{670B}\u{53CB}\u{8BF7}\u{8FDB}",
    deny: "\u{975E}\u{8BF7}\u{83AB}\u{5165}"
  }

  def init_room do
    %{gate: :close, exits: ["south", "east", "west"], laopu_present: true, laopu_living: true}
  end

  def do_push(state, player, laopu) do
    if state.gate == :open do
      {:error, "\u{5927}\u{95E8}\u{5F00}\u{7740}\u{5462}\u{FF0C}\u{4F60}\u{8FD8}\u{63A8}\u{4EC0}\u{4E48}\u{FF1F}"}
    else
      new_state, msgs = _do_push(state, player, laopu)
      {:ok, new_state, msgs}
    end
  end

  def do_close(state, player, laopu, auto_close \\ false) do
    if state.gate == :close do
      {:error, "\u{5927}\u{95E8}\u{5173}\u{7740}\u{5462}\u{FF0C}\u{4F60}\u{8FD8}\u{518D}\u{518D}\u{5173}\u{4E00}\u{904E}\u{FF1F}"}
    else
      new_state, msgs = _do_close(state, player, laopu, auto_close)
      {:ok, new_state, msgs}
    end
  end

  def auto_close_timer(state, laopu) do
    if state.gate == :open do
      do_close(state, nil, laopu, true)
    else
      {:noop, state}
    end
  end

  def check_valid_leave(state, player, dir, laopu) do
    if dir != "north" or not laopu.living do
      {:passthrough}
    else
      cond do
        laopu.is_owner?(player) -> {:allow, "\u{8BF7}\u{8FDB}"}
        laopu.is_owner_permit?(player) -> {:allow, "\u{670B}\u{53CB}\u{8BF7}\u{8FDB}"}
        true -> {:deny, "\u{975E}\u{8BF7}\u{83AB}\u{5165}"}
      end
    end
  end

  def generate_long(base_long, state, laopu_present) do
    msg = "    "
    if laopu_present do msg = msg <> "\u{8001}\u{5BB6}\u{4EBA}\u{626B}\u{843D}\u{843D}" end
    msg = msg <> (if state.gate == :open do "\u{5927}\u{95E8}\u{75C5}\u{5F00}" else "\u{5927}\u{95E8}\u{7DFC}\u{95ED}" end)
    base_long <> sort_string(msg, 60, 0)
  end

  defp _do_push(state, player, laopu) do
    msgs = []
    msg_type = cond do
      laopu.owner?(player) -> :owner
      not laopu.living or not laopu.present -> :nobody
      not laopu.owner?(player) and not laopu.owner_permit?(player) -> :laopu_for_permit
      laopu.living -> :laopu_opens
      true -> :nobody
    end
    room_msg = case msg_type do
      :owner -> format_msg("\u{63A8}\u{95E8}\u{6D88}\u{606F}", player)
      :laopu_for_owner -> format_msg("\u{8001}\u{4EDF}\u{5E2E}\u{4E3B}\u{4EBA}\u{5F00}\u{95E8}", player)
      :laopu_for_permit -> format_msg("\u{62E6}\u{4F4F} {respect} \u{8BF7}\u{56DE}", player, respect_title(player))
      :laopu_opens -> format_msg("\u{8001}\u{4EDF}\u{5F00}\u{95E8}", player)
      :nobody -> "\u{5927}\u{95E8}\u{88AB}\u{6253}\u{5F00}"
    end
    msgs = [type: :vision, target: :room, text: room_msg] ++ msgs
    msgs = [type: :broadcast, target: :zoudao, text: "\u{5927}\u{95E8}\u{88AB}\u{63A8}\u{5F00}"] ++ msgs
    new_state = %{state | gate: :open, exits: state.exits ++ ["north"]}
    msgs = [type: :sync_room, target: "/d/room/panlong/zoudao", updates: %{"exits/south" => "qianting.ex", "gate" => :open}] ++ msgs
    msgs = [type: :cancel_timer, name: :qianting_auto_close] ++ msgs
    msgs = [type: :set_timer, name: :qianting_auto_close, delay: 10000, callback: {__MODULE__, :auto_close_timer, []}] ++ msgs
    {new_state, Enum.reverse(msgs)}
  end

  defp _do_close(state, player, laopu, auto_close) do
    msgs = []
    msg_type = cond do
      auto_close -> :nobody
      laopu.owner?(player) -> :owner_self
      not laopu.living or not laopu.present -> :nobody
      laopu.owner?(player) -> :laopu_for_owner
      laopu.living -> :laopu_closes
      true -> :nobody
    end
    room_msg = case msg_type do
      :owner -> format_msg("\u{4E3B}\u{4EBA}\u{5173}\u{95E8}", player)
      :owner_self -> format_msg("\u{81EA}\u{5DF1}\u{5173}\u{95E8}", player)
      :laopu_for_owner -> format_msg("\u{8001}\u{4EDF}\u{5E2E}\u{4E3B}\u{4EBA}\u{5173}\u{95E8}", player)
      :laopu_closes -> format_msg("\u{8001}\u{4EDF}\u{5173}\u{95E8}", player)
      :nobody -> "\u{5927}\u{95E8}\u{88AB}\u{5173}\u{4E0A}"
    end
    msgs = [type: :vision, target: :room, text: room_msg] ++ msgs
    msgs = [type: :broadcast, target: :zoudao, text: "\u{5927}\u{95E8}\u{88AB}\u{5173}\u{4E0A}"] ++ msgs
    new_state = %{state | gate: :close, exits: state.exits -- ["north"]}
    msgs = [type: :sync_room, target: "/d/room/panlong/zoudao", updates: %{"exits/south" => :delete, "gate" => :close}] ++ msgs
    {new_state, Enum.reverse(msgs)}
  end

  defp format_msg(template, player, extra \\ []) do
    s = template
    |> String.replace("$N", player.name)
    |> String.replace("$n", "\u{8001}\u{4EDF}")
    |> String.replace("{respect}", respect_title(player))
    Enum.reduce(extra, s, fn {k, v}, acc -> String.replace(acc, "{" <> k <> "}", v) end)
  end

  defp respect_title(player) do
    case player.shen do
      s when s > 10000 -> "\u{5927}\u{4F20}"
      s when s > 5000 -> "\u{4F20}\u{58EB}"
      s when s > 500 -> "\u{826F}\u{5584}"
      s when s > -500 -> "\u{5C11}\u{4F20}"
      s when s > -5000 -> "\u{6076}\u{5F92}"
      _ -> "\u{9B54}\u{5934}"
    end
  end

  defp sort_string(str, width, indent) do
    String.replace(str, "\u{3002}", "\u{3002}\n")
    |> String.split("\n")
    |> Enum.map(&String.pad_leading(&1, width))
    |> Enum.join("\n")
  end
end