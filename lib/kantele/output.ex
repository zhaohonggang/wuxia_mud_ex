defmodule Kantele.Output.Macros do
  @moduledoc """
  Helper macros for defining semantic colors
  """

  @doc """
  Define a semantic color

  Available options:
  - foreground
  - background
  - underline
  """
  defmacro color(tag_name, options) do
    options =
      options
      |> Enum.map(fn {key, value} ->
        {to_string(key), to_string(value)}
      end)
      |> Enum.into(%{})

    quote do
      def parse({:open, unquote(tag_name), attributes}, context) do
        color_attributes = Map.merge(attributes, unquote(Macro.escape(options)))

        tags = [
          {:open, "color", color_attributes},
          {:open, unquote(tag_name), attributes}
        ]

        Map.put(context, :data, context.data ++ tags)
      end

      def parse({:close, unquote(tag_name)}, context) do
        tags = [
          {:close, unquote(tag_name)},
          {:close, "color"}
        ]

        Map.put(context, :data, context.data ++ tags)
      end
    end
  end

  @doc """
  Display metadata attributes on tags
  """
  defmacro metadata(tag_name, color, block) do
    quote do
      def parse({:open, unquote(tag_name), attributes}, context) do
        tag_stack = [{:open, unquote(tag_name), attributes} | context.meta.tag_stack]
        meta = Map.put(context.meta, :tag_stack, tag_stack)

        context
        |> Map.put(:data, context.data ++ [{:open, unquote(tag_name), attributes}])
        |> Map.put(:meta, meta)
      end

      def parse({:close, unquote(tag_name)}, context) do
        [{:open, unquote(tag_name), attributes} | tag_stack] = context.meta.tag_stack
        meta = Map.put(context.meta, :tag_stack, tag_stack)

        tags = [
          {:close, unquote(tag_name)},
          {:open, "color", %{"foreground" => unquote(Macro.escape(color))}},
          unquote(block).(attributes),
          {:close, "color"}
        ]

        context
        |> Map.put(:data, context.data ++ tags)
        |> Map.put(:meta, meta)
      end
    end
  end

  @doc """
  Define a tag with a tooltip
  """
  defmacro tooltip(tag_name, text_key) do
    quote do
      def parse({:open, unquote(tag_name), attributes}, context) do
        tags = [
          {:open, "tooltip", %{"text" => Map.get(attributes, unquote(text_key))}},
          {:open, unquote(tag_name), attributes}
        ]

        Map.put(context, :data, context.data ++ tags)
      end

      def parse({:close, unquote(tag_name)}, context) do
        tags = [
          {:close, unquote(tag_name)},
          {:close, "tooltip"}
        ]

        Map.put(context, :data, context.data ++ tags)
      end
    end
  end
end

defmodule Kantele.Output.SemanticColors do
  @moduledoc """
  Transform semantic tags into color tags
  """

  use Kalevala.Output

  import Kantele.Output.Macros, only: [color: 2]

  color("character", foreground: "yellow")
  color("exit", foreground: "white")
  color("item", foreground: "cyan")
  color("text", foreground: "green")
  color("room-title", foreground: "blue", underline: true)
  color("hp", foreground: "red")
  color("sp", foreground: "blue")
  color("ep", foreground: "169,114,218")

  @impl true
  def parse(datum, context) do
    Map.put(context, :data, context.data ++ [datum])
  end
end

defmodule Kantele.Output.AdminTags do
  @moduledoc """
  Parse admin specific tags

  Display things like item instance ids when present
  """

  use Kalevala.Output

  import Kalevala.Character.View.Macro, only: [sigil_i: 2]
  import Kantele.Output.Macros, only: [metadata: 3]

  @impl true
  def init(opts) do
    %Context{
      data: [],
      opts: opts,
      meta: %{
        tag_stack: []
      }
    }
  end

  metadata("character", "95,95,95", fn attributes ->
    ~i(##{attributes["id"]})
  end)

  metadata("item-instance", "95,95,95", fn attributes ->
    ~i(##{attributes["id"]})
  end)

  metadata("room-title", "95,95,95", fn attributes ->
    ~i( #{attributes["id"]} [#{attributes["x"]},#{attributes["y"]},#{attributes["z"]}])
  end)

  @impl true
  def parse(datum, context) do
    Map.put(context, :data, context.data ++ [datum])
  end
end

defmodule Kantele.Output.Tooltips do
  @moduledoc """
  Process tags to wrap in a tooltip tag

  Parse out a specific key to generate a new tooltip with the appropriate text
  """

  use Kalevala.Output

  # import Kantele.Output.Macros, only: [tooltip: 2]

  @impl true
  def init(opts) do
    %Context{
      data: [],
      opts: opts,
      meta: %{}
    }
  end

  @impl true
  def parse(datum, context) do
    Map.put(context, :data, context.data ++ [datum])
  end
end

defmodule Kantele.Output.Commands do
  @moduledoc """
  Wrap tags in command tags to send text by clicking
  """

  use Kalevala.Output

  @impl true
  def init(opts) do
    %Kalevala.Output.Context{
      data: [],
      opts: opts,
      meta: %{}
    }
  end

  def parse({:open, "exit", attributes}, context) do
    tags = [
      {:open, "command", %{"send" => attributes["name"]}},
      {:open, "exit", attributes}
    ]

    Map.put(context, :data, context.data ++ tags)
  end

  def parse({:close, "exit"}, context) do
    tags = [
      {:close, "exit"},
      {:close, "command"}
    ]

    Map.put(context, :data, context.data ++ tags)
  end

  @impl true
  def parse(datum, context) do
    Map.put(context, :data, context.data ++ [datum])
  end
end

defmodule Kantele.Output.Snoop do
  @moduledoc """
  Snoop 消息格式化（对应 `feature/message.c receive_snoop`）

  LPC ANSI 序列：
  - ESC "[256D" - 光标上移行首
  - ESC "[K" - 清除到行尾
  - ESC "[1A" - 上箭头
  - NOR - 清除属性
  - BBLU WHT - 蓝底白字

  处理流程：
  1. 跳过提示行（ESC "[256D" 且非 ESC "[K"）
  2. 去除 ESC "[1A"
  3. NOR 替换为 NOR BBLU WHT（蓝底白字）
  4. 前后添加颜色序列
  5. 按 2560 字符分块
  """

  @max_size 2560
  @esc_256d "\e[256D"
  @esc_k "\e[K"
  @esc_1a "\e[1A"
  @bblu_wht "\e[44;37m"
  @nor IO.ANSI.reset()
  @cursor_left "\e[1D"

  @doc """
  格式化 snoop 消息，返回分块后的消息列表

  返回 `[msg1, msg2, ...]`
  """
  def format(msg) when is_binary(msg) do
    if skip_prompt?(msg) do
      []
    else
      msg
      |> strip_up_arrow()
      |> wrap_nor()
      |> wrap_message()
      |> chunk()
    end
  end

  defp skip_prompt?(msg) do
    String.starts_with?(msg, @esc_256d) and not String.contains?(msg, @esc_k)
  end

  defp strip_up_arrow(msg) do
    String.replace(msg, @esc_1a, "")
  end

  defp wrap_nor(msg) do
    String.replace(msg, @nor, @nor <> @bblu_wht)
  end

  defp wrap_message(msg) do
    @bblu_wht <> msg <> @nor <> " " <> @cursor_left
  end

  defp chunk(msg) when byte_size(msg) <= @max_size do
    [msg]
  end

  defp chunk(msg) do
    do_chunk(msg, [])
  end

  defp do_chunk(<<head::binary-size(@max_size), rest::binary>>, acc) do
    do_chunk(rest, [head | acc])
  end

  defp do_chunk(rest, acc) do
    Enum.reverse([rest | acc])
  end
end
