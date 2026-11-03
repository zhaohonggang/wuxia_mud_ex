defmodule Kantele.Character.SetupView do
  @moduledoc """
  新玩家注册问答（阎罗殿）的视图与提示语。

  对应 LPC `yanluodian.c` 的 `do_wash`/`do_born` 与 `updated.c` 的 `born_player`：
  性别 → 洗点(washto) → 投胎(born) → 赠「与生俱来」特技。
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  @doc "进入阎罗殿的叙事开场"
  def render("welcome", _assigns) do
    %EventText{
      topic: "Setup.Welcome",
      data: %{},
      text: ~s"""
      阎 罗 殿

      阎罗殿内阴森恐怖，让你感到一阵阵刺骨的寒意，两旁列着牛头马面、冥府狱卒，
      各个威严肃穆。十殿阎罗尽皆在此，地藏王端坐大堂之上，不怒自威，你的腿脚
      不禁都有些软了。大殿角落有一个石头砌成的池子，池中潭水清澈却不见底。

      水池旁边有一个牌子(paizi)：投胎乃人生大事，切记不可草率！先选好先天属性，
      再去投胎(born)吧。
      """
    }
  end

  @doc "问答①：性别"
  def render("gender", _assigns) do
    %EventText{
      topic: "Setup.Gender",
      data: %{},
      text: ~s(请选择你的 {color foreground="white"}性别{/color}（输入 m / 男，或 f / 女）：)
    }
  end

  @doc "问答②引导：洗点规则"
  def render("washto_intro", _assigns) do
    %EventText{
      topic: "Setup.WashtoIntro",
      data: %{},
      text: ~s"""
      你来到忘忧池边。牛头恶狠狠地说：要投胎，先洗去前世尘缘、重塑先天属性！

      请输入你的 {color foreground="white"}先天四项属性{/color}（膂力 悟性 根骨 身法，
      每项 {color foreground="yellow"}10–30{/color}，且 {color foreground="yellow"}四项之和必须为 80{/color}）。
      例如：{color foreground="cyan"}20 20 20 20{/color}
      容貌(per)与福缘(kar)由天意随机定夺（5–30）。
      """
    }
  end

  @doc "问答②：输入洗点属性"
  def render("washto", _assigns) do
    %EventText{
      topic: "Setup.Washto",
      data: %{},
      text: ~s(请分配先天属性（格式：膂力 悟性 根骨 身法）：)
    }
  end

  @doc "问答②错误回显"
  def render("washto_error", %{reason: reason}) do
    %EventText{
      topic: "Setup.WashtoError",
      data: %{reason: reason},
      text: ~s({color foreground="red"}#{reason}{/color} 请重新输入（格式：膂力 悟性 根骨 身法）：)
    }
  end

  @doc "洗点成功展示"
  def render("washed", %{str: str, int: int, con: con, dex: dex, per: per, kar: kar}) do
    %EventText{
      topic: "Setup.Washed",
      data: %{str: str, int: int, con: con, dex: dex, per: per, kar: kar},
      text: ~s"""
      你跳入忘忧池，顿时被一股激流卷了进去……只听“啪”的一声，你被湿漉漉地抛了出来。

      你这次获得的四项先天天赋分别是：
        膂力：【 {color foreground="hiyellow"}#{str}{/color} 】 悟性：【 {color foreground="hiyellow"}#{int}{/color} 】
        根骨：【 {color foreground="hiyellow"}#{con}{/color} 】 身法：【 {color foreground="hiyellow"}#{dex}{/color} 】
        容貌：【 {color foreground="hiyellow"}#{per}{/color} 】 福缘：【 {color foreground="hiyellow"}#{kar}{/color} 】
      """
    }
  end

  @doc "问答③引导：出生地列表"
  def render("born_intro", _assigns) do
    %EventText{
      topic: "Setup.BornIntro",
      data: %{},
      text: ~s"""
      牛头飞起一脚，把你从池中踢出，喝道：洗好了就快去投胎！

      可选出生地（输入中文地名）：
        1. {color foreground="cyan"}扬州人氏{/color}
        2. {color foreground="cyan"}欧阳世家{/color}（西域·白驼山，姓欧阳）
        3. {color foreground="cyan"}关外胡家{/color}（关外·小屋，姓胡）
        4. {color foreground="cyan"}中原苗家{/color}（中原·苗家后厅，姓苗）
        5. {color foreground="cyan"}段氏皇族{/color}（大理·王府，姓段）
        6. {color foreground="cyan"}慕容世家{/color}（江南·燕子坞，姓慕容）
      """
    }
  end

  @doc "问答③：输入出生地"
  def render("born", _assigns) do
    %EventText{
      topic: "Setup.Born",
      data: %{},
      text: ~s(请投胎选择你的出生地（如：扬州人氏）：)
    }
  end

  @doc "问答③错误回显"
  def render("born_error", %{reason: reason}) do
    %EventText{
      topic: "Setup.BornError",
      data: %{reason: reason},
      text: ~s({color foreground="red"}#{reason}{/color} 请重新输入出生地（如：扬州人氏）：)
    }
  end

  @doc "投胎完成"
  def render("born_done", %{skills: skills}) do
    skill_text =
      case skills do
        [] ->
          "你似乎与任何先天特技无缘。"

        ids ->
          names = Enum.map(ids, &Kantele.Character.BornPlayer.display_name/1)
          "你与生俱来的技能有：" <> Enum.join(names, "、") <> "。"
      end

    %EventText{
      topic: "Setup.BornDone",
      data: %{skills: skills},
      text: ~s"""
      牛头飞起一脚，将你踢了出去。

      #{skill_text}

      你揉揉眼睛，迷惘地望着这个陌生的世界。
      """
    }
  end
end
