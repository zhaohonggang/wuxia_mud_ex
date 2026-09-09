defmodule Kantele.World.Story do
  @moduledoc """
  storyd.c 移植：定时挑选并推进「全服叙事」剧情（Q3）。

  - 上一个故事结束/启动后，经 `start_delay_ms`（默认 1800 + random(300) 秒，测试可注入）
    挑下一个故事并逐行推进（每行间隔 `step_delay_ms`，默认 1s）；
  - 每个 step 调 `Kantele.World.Story.Behaviour.step/2` 纯函数推进：
    - `{:text, ...}` 全服播报（`Kantele.Communication.announce("general")`）；
    - `{:action, fun, ...}` 执行动作（掉落/选人/授技），返回值若是字符串再播报一行；
    - `{:done, ...}` 收尾并排下一场；
  - `$N`/`$F`/`$ID` 占位替换由各 story 模块在其 `step/2` 内完成（对应 LPC `replace_string`）；
  - **所有定时用 `Scheduler.schedule_once` 链式**（`schedule_recurring` 取消有 bug 勿用）。

  测试/运维可注入实例：
  `start_link([name: :anonymous, start_delay_ms: 10, step_delay_ms: 10,
  stories: [{:demo, MyDemoStory}]])`；`tick/1` 强制推进一档。
  """

  use GenServer

  require Logger

  alias Kantele.Communication
  alias Kantele.Scheduler

  @default_step_delay_ms 1000

  defstruct [
    :running,
    :step,
    :inner,
    :start_delay_ms,
    :step_delay_ms,
    :stories,
    :history
  ]

  # ---- API ----

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc "当前剧情：`{:ok, module, step}` 或 `:none`"
  def current(server \\ __MODULE__), do: GenServer.call(server, :current)

  @doc "立即开始指定剧情（留空则随机选）；已有剧情进行中返回 {:error, :story_running}"
  def start_story(server \\ __MODULE__, name \\ nil),
    do: GenServer.call(server, {:start_story, name})

  @doc "强制推进一档（test/运维用）；无在进行剧情时返回 :idle"
  def tick(server \\ __MODULE__), do: GenServer.call(server, :tick)

  @doc "提前结束当前剧情，排下一场"
  def stop_story(server \\ __MODULE__), do: GenServer.call(server, :stop_story)

  # ---- GenServer ----

  @impl true
  def init(opts) do
    stories = (opts[:stories] || default_stories())

    state = %__MODULE__{
      stories: normalize_stories(stories),
      start_delay_ms: opts[:start_delay_ms] || default_start_delay_ms(),
      step_delay_ms: opts[:step_delay_ms] || @default_step_delay_ms,
      history: %{}
    }

    schedule_next(state.start_delay_ms, self())
    {:ok, state}
  end

  @impl true
  def handle_call(:current, _from, state) do
    {:reply, if(state.running, do: {:ok, state.running, state.step}, else: :none), state}
  end

  def handle_call(:tick, _from, state) do
    if state.running do
      {:reply, :ok, advance(state)}
    else
      {:reply, :idle, state}
    end
  end

  def handle_call(:stop_story, _from, state) do
    state = %{state | running: nil, step: 0, inner: nil}
    schedule_next(state.start_delay_ms, self())
    {:reply, :ok, state}
  end

  def handle_call({:start_story, name}, _from, state) do
    case state.running do
      nil ->
        case pick(state, name) do
          {:ok, module, module_name} ->
            Logger.info("story selected: #{module_name}")

            state = %{state | running: module, step: 0, inner: module.init_state()}

            {:reply, :ok, advance(state)}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _running ->
        {:reply, {:error, :story_running}, state}
    end
  end

  @impl true
  def handle_info(:next, state) do
    {:noreply, advance(state)}
  end

  # ---- 推进 ----

  defp advance(state) do
    case state.running do
      nil ->
        case pick(state, nil) do
          {:ok, module, module_name} ->
            schedule_next(state.step_delay_ms, self())

            %{
              state
              | running: module,
                step: 0,
                inner: module.init_state(),
                history: Map.put(state.history, module_name, System.system_time(:millisecond))
            }

          {:error, :no_story_available} ->
            schedule_next(state.start_delay_ms, self())
            state
        end

      module ->
        case module.step(state.step, state.inner) do
          {:text, text, inner} ->
            broadcast(module, text)
            schedule_next(state.step_delay_ms, self())
            %{state | step: state.step + 1, inner: inner}

          {:action, fun, inner} ->
            case safe_run(fun) do
              text when is_binary(text) -> broadcast(module, text)
              _ -> :ok
            end

            schedule_next(state.step_delay_ms, self())
            %{state | step: state.step + 1, inner: inner}

          {:done, _inner} ->
            schedule_next(state.start_delay_ms, self())
            %{state | running: nil, step: 0, inner: nil}
        end
    end
  end

  defp pick(state, name) do
    case name do
      nil ->
        available =
          Enum.filter(state.stories, fn {_module_name, _module} ->
            # v1 不按冷却过滤，避免故事太少时长时间无故事
            true
          end)

        case available do
          [] ->
            {:error, :no_story_available}

          _ ->
            {module_name, module} = Enum.random(available)
            {:ok, module, module_name}
        end

      _ ->
        case Enum.find(state.stories, fn {module_name, _module} ->
               to_string(module_name) == to_string(name)
             end) do
          nil -> {:error, :unknown_story}
          {module_name, module} -> {:ok, module, module_name}
        end
    end
  end

  defp broadcast(module, text) do
    Communication.announce("general", module.prompt() <> " " <> text <> "\n")
  rescue
    e -> Logger.warn("story broadcast failed - #{Exception.message(e)}")
  catch
    :exit, reason -> Logger.warn("story broadcast failed - #{inspect(reason)}")
  end

  defp safe_run(fun) do
    fun.()
  rescue
    e ->
      Logger.warn("story step action failed - #{Exception.message(e)}")
      nil
  catch
    :exit, reason ->
      Logger.warn("story step action failed - #{inspect(reason)}")
      nil
  end

  defp schedule_next(ms, pid) do
    Scheduler.schedule_once(ms, fn -> send(pid, :next) end)
  end

  defp default_start_delay_ms() do
    # LPC: start_story 在 1800 + random(300) 秒后触发
    (1800 + :rand.uniform(300)) * 1000
  end

  defp normalize_stories(stories) do
    Enum.map(stories, fn
      {name, module} ->
        {name, module}

      module ->
        name = module |> Module.split() |> List.last() |> String.downcase()
        {name, module}
    end)
  end

  @doc false
  def default_stories() do
    [
      Kantele.World.Story.Guanzhang,
      Kantele.World.Story.Laojun,
      Kantele.World.Story.Liandan,
      Kantele.World.Story.Nanji,
      Kantele.World.Story.Mengzi,
      Kantele.World.Story.Feng,
      Kantele.World.Story.Sun,
      Kantele.World.Story.Lighting,
      Kantele.World.Story.Water,
      Kantele.World.Story.Bizhen,
      Kantele.World.Story.Guigu,
      Kantele.World.Story.Huanyin,
      Kantele.World.Story.Sanfenjian,
      Kantele.World.Story.Challenge
    ]
  end
end