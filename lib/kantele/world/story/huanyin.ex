defmodule Kantele.World.Story.Huanyin do
  @moduledoc "story:huanyin 幻阴指法——武林旧事（LPC huanyin.c，简化版）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
  alias Kantele.World.Story.Lines

  @impl true
  def init_state() do
    case Gift.random_player() do
      nil ->
        %{}

      player ->
        %{name: player.name, id: player.id, room_id: player.room_id}
    end
  end

  @impl true
  def prompt(), do: "{color foreground=\"green\"}【武林传闻】{/color}"

  @impl true
  def step(index, inner) do
    lines = [
      "江湖上有一门失传已久的功夫唤作幻阴指法，据说指风过处，寒气入骨，中者如坠冰窟。",
      "数十年前，这门功夫的传人一夜之间销声匿迹，只留下半本残卷，辗转流落江湖。",
      "这一日黄昏，$N正与众人茶楼闲谈，忽一灰袍人抛下一卷旧书，道：有缘者得之。",
      "$N展开书卷，指尖竟丝丝发凉，那书上赫然写着四个字：幻阴指法。",
      "你抬起头时，那灰袍人已消失在人海之中。",
      {:action, fn ->
        case Gift.drop_to_room(inner[:room_id], "book/guigu", "\n“啪”的一声，一本书掉到你面前。\n\n") do
          :ok -> "江湖传言，幻阴指法的残卷终于又现人间，无数门派弟子闻风而动。"
          _other -> nil
        end
      end}
    ]

    Lines.step_lines(lines, index, inner)
  end
end