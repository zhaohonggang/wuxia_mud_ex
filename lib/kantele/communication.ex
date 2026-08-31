defmodule Kantele.Communication.BroadcastChannel do
  use Kalevala.Communication.Channel
end

defmodule Kantele.Communication do
  @moduledoc false

  use Kalevala.Communication

  require Logger

  @impl true
  def initial_channels() do
    [
      {"general", Kantele.Communication.BroadcastChannel, []},
      {"rumor", Kantele.Communication.BroadcastChannel, []},
      {"bill", Kantele.Communication.BroadcastChannel, []}
    ]
  end

  @doc """
  系统公告使用的虚拟角色

  频道消息的 character 字段在玩家侧渲染（telnet 视图与 Web 端 reducer 都会读
  id/name），无 conn 的系统公告挂上它即可复用整条渲染链路。
  """
  def system_character() do
    %{id: "", name: "系统", description: ""}
  end

  @doc """
  以系统身份向频道发布公告（供 Kickoff 等无 conn 的进程使用）

  发布链路上的任何异常/退出都吞掉只记日志，返回 :ok 或 {:error, reason}，
  保证调用方不受影响。
  """
  def announce(channel_name, text) do
    try do
      event = %Kalevala.Event{
        acting_character: nil,
        from_pid: self(),
        topic: Kalevala.Event.Message,
        data: %Kalevala.Event.Message{
          channel_name: channel_name,
          character: system_character(),
          id: Kalevala.Event.Message.generate_id(),
          text: text,
          type: "announcement"
        }
      }

      publish(channel_name, event, [])
    rescue
      e ->
        Logger.warn("Failed to announce on #{channel_name} - #{Exception.message(e)}")

        {:error, :announce_failed}
    catch
      :exit, reason ->
        Logger.warn("Failed to announce on #{channel_name} - #{inspect(reason)}")

        {:error, :announce_failed}
    end
  end
end
