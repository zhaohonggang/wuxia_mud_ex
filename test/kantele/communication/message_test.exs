defmodule Kantele.Communication.MessageTest do
  use ExUnit.Case, async: true

  alias Kantele.Communication.Message

  describe "color_class (message.c 消息类→颜色)" do
    test "语义类映射" do
      assert Message.color_class("info") == {"\e[36m", "\e[0m"}
      assert Message.color_class("success") == {"\e[32m", "\e[0m"}
      assert Message.color_class("warning") == {"\e[33m", "\e[0m"}
      assert Message.color_class("error") == {"\e[31m", "\e[0m"}
      assert Message.color_class("danger") == {"\e[31m", "\e[0m"}
    end

    test "裸色类与非映射" do
      assert Message.color_class("HIM") == {"\e[35m", "\e[0m"}
      assert Message.color_class("CYN") == {"\e[36m", "\e[0m"}
      assert Message.color_class("unknown") == nil
      assert Message.color_class(nil) == nil
    end

    test "s 染色包装" do
      assert Message.s("error", "哦不") == "\e[31m哦不\e[0m"
      assert Message.s("unknown", "裸文本") == "裸文本"
    end
  end

  describe "prompt_prefix (message.c prompt)" do
    test "默认 / 自定义" do
      assert Message.prompt_prefix(nil) == "> "
      assert Message.prompt_prefix("自定义") == "自定义> "
    end

    test "time/date/hp/path" do
      assert Message.prompt_prefix("time", %{time: "12:00:00"}) == "\e[36m12:00:00> "
      assert Message.prompt_prefix("date", %{date: "2026-08-29"}) == "\e[36m2026-08-29> "
      assert Message.prompt_prefix("hp", %{hp: "100/200"}) == "\e[32m100/200> "
      assert Message.prompt_prefix("path", %{path: "/data/"}) == "\e[36m/data/> "
    end
  end

  describe "buffer (message.c 输入缓冲)" do
    test "入缓冲/上限丢弃" do
      assert Message.buffer_message([], "m1") == {:buffered, ["m1"]}

      big = List.duplicate("m", 500)
      assert Message.buffer_message(big, "over") == {:dropped, big}
    end

    test "drain_buffer 返回暂存讯息头" do
      {msgs, buf} = Message.drain_buffer(["a", "b"])
      assert buf == []
      assert hd(msgs) == "\e[1m[输入时暂存讯息]\e[0m\n"
      assert tl(msgs) == ["a", "b"]
    end
  end

  describe "written 状态机" do
    test "clear_written/waiting" do
      assert Message.is_waiting_command?(Message.write_prompt_mark(nil))
      refute Message.is_waiting_command?(Message.clear_written(nil))
      refute Message.is_waiting_command?(Message.reset_written(nil))
    end
  end
end
