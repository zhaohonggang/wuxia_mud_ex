defmodule Kantele.Character.LoginView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("welcome", assigns) do
    %EventText{
      topic: "Login.Welcome",
      data: %{powered_by: "Kalevala #{Kalevala.version()}"},
      text: render("welcome.text", assigns)
    }
  end

  def render("welcome.text", _assigns) do
    ~E"""
    Welcome to
    {color foreground="256:39"}
     __   ___       __      _____  ___  ___________  _______  ___       _______
    |/"| /  ")     /""\    (\"   \|"  \("     _   ")/"     "||"  |     /"     "|
    (: |/   /     /    \   |.\\   \    |)__/  \\__/(: ______)||  |    (: ______)
    |    __/     /' /\  \  |: \.   \\  |   \\_ /    \/    |  |:  |     \/    |
    (// _  \    //  __'  \ |.  \    \. |   |.  |    // ___)_  \  |___  // ___)_
    |: | \  \  /   /  \\  \|    \    \ |   \:  |   (:      "|( \_|:  \(:      "|
    (__|  \__)(___/    \___)\___|\____\)    \__|    \_______) \_______)\_______)
    {/color}

    <%= render("powered-by", %{}) %>
    """
  end

  def render("powered-by", _assigns) do
    [
      ~s(Powered by {color foreground="256:39"}Kalevala{/color} 🧝 ),
      ~s({color foreground="cyan"}v#{Kalevala.version()}{/color}.)
    ]
  end

  def render("name", _assigns) do
    %EventText{
      topic: "Login.PromptUsername",
      data: %{},
      text: ~s(What is your {color foreground="white"}name{/color}? )
    }
  end

  def render("password", _assigns) do
    %EventText{
      topic: "Login.PromptPassword",
      data: %{},
      text: "Password: "
    }
  end

  def render("signed-in", %{username: username}) do
    %EventText{
      topic: "Login.SignedIn",
      data: %{username: username},
      text: """

      Welcome {color foreground="white"}#{username}{/color}. Thanks for signing in.
      """
    }
  end

  def render("character-name", _assigns) do
    %EventText{
      topic: "Login.PromptCharacter",
      data: %{},
      text: "What is your character name? "
    }
  end

  # 角色选择 token 过期/无效（浏览器挂太久）——退回用户名步骤重新登录
  def render("token-expired", %{reason: reason}) do
    text =
      case reason do
        :expired -> "\nYour character selection expired. Please sign in again.\n"
        _ -> "\nYour character selection could not be verified. Please sign in again.\n"
      end

    %EventText{
      topic: "Login.TokenExpired",
      data: %{reason: reason},
      text: text
    }
  end

  def render("enter-world", %{character: character}) do
    %EventText{
      topic: "Login.EnterWorld",
      data: %{
        character: %{
          name: character.name
        }
      },
      text: [
        ~s(Welcome to the world of {color foreground="256:39"}Kantele{/color}, {color foreground="white"}),
        character.name,
        ~s({/color}.\n)
      ]
    }
  end
end
