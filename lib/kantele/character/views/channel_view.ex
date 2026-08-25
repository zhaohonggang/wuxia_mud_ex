defmodule Kantele.Character.ChannelView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText
  alias Kantele.Character.CharacterView

  def render("name", %{name: name}) do
    ~i({color foreground="white"}[#{name}]{/color})
  end

  def render("echo", %{channel_name: channel_name, character: character, id: id, text: text}) do
    %EventText{
      topic: "Channel.Broadcast",
      data: %{
        channel_name: channel_name,
        character: character,
        id: id,
        text: text
      },
      text: [
        render("name", %{name: channel_name}),
        ~i( You say, ),
        ~i("{color foreground="green"}#{text}{/color}"\n)
      ]
    }
  end

  def render("listen", %{channel_name: channel_name, character: character, id: id, text: text}) do
    %EventText{
      topic: "Channel.Broadcast",
      data: %{
        channel_name: channel_name,
        character: character,
        id: id,
        text: text
      },
      text: [
        render("name", %{name: channel_name}),
        ~i( #{CharacterView.render("name", %{character: character})} says, ),
        ~i("{color foreground="green"}#{text}{/color}"\n)
      ]
    }
  end

  # 系统公告（如世界加载失败广播）：data 里仍带一个虚拟角色，
  # 保证 Web 端 channelReducer 读 character.id/name 不出错
  def render("system", %{channel_name: channel_name, text: text}) do
    character = Kantele.Communication.system_character()

    %EventText{
      topic: "Channel.Broadcast",
      data: %{
        channel_name: channel_name,
        character: character,
        id: nil,
        text: text
      },
      text: [
        render("name", %{name: channel_name}),
        ~i( {color foreground="yellow"}#{character.name}:{/color} {color foreground="yellow"}#{
          text
        }{/color}\n)
      ]
    }
  end
end
