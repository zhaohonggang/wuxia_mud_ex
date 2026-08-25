defmodule Kantele.Brain do
  @moduledoc """
  Load and parse brain data into behavior tree structs
  """

  @brains_path "data/brains"

  @doc """
  Load brain data from the path

  Defaults to `#{@brains_path}`
  """
  def load_all(path \\ @brains_path) do
    File.ls!(path)
    |> Enum.filter(fn file ->
      String.ends_with?(file, ".ucl")
    end)
    |> Enum.map(fn file ->
      File.read!(Path.join(path, file))
    end)
    |> Enum.map(&Elias.parse/1)
    |> Enum.flat_map(&merge_data/1)
    |> Enum.into(%{})
  end

  defp merge_data(brain_data) do
    Enum.map(brain_data.brains, fn {key, value} ->
      {to_string(key), value}
    end)
  end

  def process_all(brains) do
    Enum.into(brains, %{}, fn {key, value} ->
      {key, process(value, brains)}
    end)
  end

  def process(brain, brains) when brain != nil do
    root = parse_node(brain, brains)

    # 条件选择器失败时会向下游返回 :error（Kalevala clean_state 无法处理），
    # 包一层 sequence 吸收错误，保证任何 brain 结构都安全
    root =
      case root do
        %Kalevala.Brain.ConditionalSelector{} ->
          %Kalevala.Brain.Sequence{nodes: [root]}

        other ->
          other
      end

    %Kalevala.Brain{root: root}
  end

  def process(_, _brains) do
    %Kalevala.Brain{
      root: %Kalevala.Brain.NullNode{}
    }
  end

  # This is `brain = brains.town_crier`
  defp parse_node("brains." <> key_path, brains) do
    parse_node(brains[key_path], brains)
  end

  # A ref `{ ref = brains.town_crier }`
  defp parse_node(%{ref: "brains." <> key_path}, brains) do
    parse_node(brains[key_path], brains)
  end

  # Sequences

  defp parse_node(%{type: "sequence", nodes: nodes}, brains) do
    %Kalevala.Brain.Sequence{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  defp parse_node(%{type: "first", nodes: nodes}, brains) do
    %Kalevala.Brain.FirstSelector{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  defp parse_node(%{type: "conditional", nodes: nodes}, brains) do
    %Kalevala.Brain.ConditionalSelector{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  defp parse_node(%{type: "conditions/" <> type} = condition, brains),
    do: parse_condition(type, condition, brains)

  defp parse_node(%{type: "actions/" <> type} = action, brains),
    do: parse_action(type, action, brains)

  @doc """
  Process a condition
  """
  def parse_condition("message-match", %{data: data}, _brains) do
    {:ok, regex} = Regex.compile(data.text, "i")

    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.MessageMatch,
      data: %{
        interested?: &Kantele.Character.SayEvent.interested?/1,
        self_trigger: data.self_trigger == "true",
        text: regex
      }
    }
  end

  def parse_condition("tell-match", %{data: data}, _brains) do
    {:ok, regex} = Regex.compile(data.text, "i")

    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.MessageMatch,
      data: %{
        interested?: &Kantele.Character.TellEvent.interested?/1,
        self_trigger: data.self_trigger == "true",
        text: regex
      }
    }
  end

  def parse_condition("state-match", %{data: data}, _brains) do
    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.StateMatch,
      data: data
    }
  end

  def parse_condition("room-enter", %{data: data}, _brains) do
    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.EventMatch,
      data: %{
        self_trigger: data.self_trigger == "true",
        topic: Kalevala.Event.Movement.Notice,
        data: %{
          direction: :to
        }
      }
    }
  end

  def parse_condition("event-match", %{data: data}, _brains) do
    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.EventMatch,
      data: %{
        self_trigger: Map.get(data, :self_trigger, "false") == "true",
        topic: data.topic,
        data: Map.get(data, :data, %{})
      }
    }
  end

  # 概率条件（A10/N3 chat_chance）
  def parse_condition("random", %{data: data}, _brains) do
    %Kalevala.Brain.Condition{
      type: Kantele.Brain.Conditions.Random,
      data: %{chance: parse_chance(data[:chance] || data["chance"])}
    }
  end

  defp parse_chance(chance) when is_integer(chance), do: chance

  defp parse_chance(chance) when is_binary(chance) do
    case Integer.parse(chance) do
      {value, _} -> value
      _ -> 0
    end
  end

  defp parse_chance(_), do: 0

  @doc """
  Process actions
  """
  def parse_action("state-set", action, _brains) do
    %Kalevala.Brain.StateSet{
      data: action.data
    }
  end

  def parse_action("say", action, _brains) do
    %Kalevala.Brain.Action{
      type: Kantele.Character.SayAction,
      data: action.data,
      delay: Map.get(action, :delay, 0)
    }
  end

  # 闲聊（A10/N3）：data %{lines: [...]}，由 ChatAction 随机挑一条说出口
  def parse_action("chat", action, _brains) do
    lines =
      case Map.get(action.data, :lines) do
        lines when is_list(lines) -> Enum.map(lines, &to_string/1)
        _ -> []
      end

    %Kalevala.Brain.Action{
      type: Kantele.Character.ChatAction,
      data: %{lines: lines},
      delay: Map.get(action, :delay, 0)
    }
  end

  def parse_action("emote", action, _brains) do
    %Kalevala.Brain.Action{
      type: Kantele.Character.EmoteAction,
      data: action.data,
      delay: Map.get(action, :delay, 0)
    }
  end

  def parse_action("flee", action, _brains) do
    %Kalevala.Brain.Action{
      type: Kantele.Character.FleeAction,
      data: %{},
      delay: Map.get(action, :delay, 0)
    }
  end

  def parse_action("combat-engage", action, _brains) do
    %Kalevala.Brain.Action{
      type: Kantele.Character.CombatEngageAction,
      data: %{},
      delay: Map.get(action, :delay, 0)
    }
  end

  def parse_action("wander", action, _brains) do
    %Kalevala.Brain.Action{
      type: Kantele.Character.WanderAction,
      data: %{},
      delay: Map.get(action, :delay, 0)
    }
  end

  def parse_action("delay-event", action, _brains) do
    %Kalevala.Brain.Action{
      type: Kantele.Character.DelayEventAction,
      data: action.data,
      delay: Map.get(action, :delay, 0)
    }
  end
end
