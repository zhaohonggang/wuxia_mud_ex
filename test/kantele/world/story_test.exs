defmodule Kantele.World.StoryTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Story

  defmodule DemoStory do
    @behaviour Kantele.World.Story.Behaviour

    @impl true
    def init_state(), do: %{}

    @impl true
    def prompt(), do: "{color foreground=\"cyan\"}【测试传闻】{/color}"

    @impl true
    def step(0, inner), do: {:text, "一行一。", inner}
    def step(1, inner), do: {:text, "一行二。", inner}
    def step(_index, inner), do: {:done, inner}
  end

  defp step_module_to_done(module, index, guard \\ 0) do
    assert guard <= 60, "module #{inspect(module)} 未能推进到 done"

    case module.step(index, %{}) do
      {:text, text, _inner} when is_binary(text) ->
        step_module_to_done(module, index + 1, guard + 1)

      {:action, fun, _inner} when is_function(fun, 0) ->
        fun.()
        step_module_to_done(module, index + 1, guard + 1)

      {:done, _inner} ->
        :ok

      other ->
        flunk("模块 #{inspect(module)} 返回了非契约结果：#{inspect(other)}")
    end
  end

  test "default_stories 覆盖 14 个模块" do
    modules = Story.default_stories()
    assert length(modules) == 14

    expected = [
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

    Enum.each(expected, fn module -> assert module in modules end)
  end

  test "全部模块契约成立：prompt 为字符串、init_state 为 map、可推进到 done（动作安全兜底）" do
    Enum.each(Story.default_stories(), fn module ->
      assert is_binary(module.prompt()), "prompt 应为字符串: #{inspect(module)}"
      assert is_map(module.init_state()), "init_state 应为 map: #{inspect(module)}"
      step_module_to_done(module, 0)
    end)
  end

  describe "GenServer（匿名实例）" do
    test "start_story/tick/current/stop_story 状态机" do
      {:ok, server} =
        Story.start_link(
          name: :anonymous,
          start_delay_ms: 60_000,
          step_delay_ms: 5,
          stories: [demo: DemoStory]
        )

      assert Story.current(server) == :none
      assert Story.tick(server) == :idle

      assert Story.start_story(server, "demo") == :ok
      assert {:ok, DemoStory, 1} = Story.current(server)

      assert Story.tick(server) == :ok
      assert {:ok, DemoStory, 2} = Story.current(server)

      assert Story.tick(server) == :ok
      assert Story.current(server) == :none
    end

    test "进行中启动第二个故事被拒绝；结束自动排下一场" do
      {:ok, server} =
        Story.start_link(
          name: :anonymous,
          start_delay_ms: 30_000,
          step_delay_ms: 5,
          stories: [demo: DemoStory]
        )

      :ok = Story.start_story(server, "demo")
      assert {:error, :story_running} = Story.start_story(server, "demo")

      Story.tick(server)
      Story.tick(server)
      Story.tick(server)

      assert Story.current(server) == :none
    end

    test "全服播报：逐行经 general 频道发出（含 prompt 前缀）" do
      :ok = Kantele.Communication.subscribe("general", [])

      {:ok, server} =
        Story.start_link(
          name: :anonymous,
          start_delay_ms: 60_000,
          step_delay_ms: 5,
          stories: [demo: DemoStory]
        )

      assert Story.start_story(server, "demo") == :ok

      assert_receive %Kalevala.Event{
        topic: Kalevala.Event.Message,
        data: %{text: text}
      }, 200

      assert text =~ "【测试传闻】"
      assert text =~ "一行一"

      Story.tick(server)

      assert_receive %Kalevala.Event{
        topic: Kalevala.Event.Message,
        data: %{text: text2}
      }, 200

      assert text2 =~ "一行二"
    end
  end
end