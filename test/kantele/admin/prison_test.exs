defmodule Kantele.Admin.PrisonTest do
  @moduledoc """
  Kantele.Admin.Prison 禁闭 daemon 的单元行为测试（不依赖 DB）。
  """
  use ExUnit.Case, async: false

  alias Kantele.Admin.Prison

  setup do
    Prison.ensure!()
    Prison.release("张三")
    Prison.release("李四")
    :ok
  end

  describe "parse_duration/1（LPC 时长单位）" do
    test "缺省 / 空串为 20 分钟" do
      assert Prison.parse_duration(nil) == {:ok, 20}
      assert Prison.parse_duration("") == {:ok, 20}
    end

    test "纯数字为分钟" do
      assert Prison.parse_duration("20") == {:ok, 20}
      assert Prison.parse_duration("45") == {:ok, 45}
    end

    test "h/d/m/y 后缀换算" do
      assert Prison.parse_duration("2h") == {:ok, 120}
      assert Prison.parse_duration("1d") == {:ok, 1440}
      assert Prison.parse_duration("1m") == {:ok, 43200}
      assert Prison.parse_duration("1y") == {:ok, 525600}
    end

    test "非法输入返回 :error" do
      assert Prison.parse_duration("abc") == :error
      assert Prison.parse_duration("2x") == :error
    end
  end

  describe "sentence / in_prison? / detail" do
    test "判处后查询为真，记录理由与执行者" do
      assert Prison.in_prison?("张三") == false

      :ok = Prison.sentence("张三", "大巫", 20, "flood")

      assert Prison.in_prison?("张三") == true
      detail = Prison.detail("张三")
      assert detail.reason == "flood"
      assert detail.by == "大巫"
      assert detail.minutes == 20
      assert detail.until > System.system_time(:second)
    end

    test "理由不在白名单时拒绝，不产生刑期" do
      assert {:error, :invalid_reason} = Prison.sentence("张三", "大巫", 20, "whatever")
      assert Prison.in_prison?("张三") == false
    end

    test "时长 <= 0 时拒绝" do
      assert {:error, :invalid_duration} = Prison.sentence("张三", "大巫", 0, "flood")
      assert Prison.in_prison?("张三") == false
    end

    test "不同玩家互不影响" do
      :ok = Prison.sentence("张三", "大巫", 20, "flood")
      :ok = Prison.sentence("李四", "大巫", 60, "rude")

      assert Prison.in_prison?("张三") == true
      assert Prison.in_prison?("李四") == true
      assert length(Prison.query_all()) == 2
    end
  end

  describe "release / query_all" do
    test "提前释放后查询为假" do
      :ok = Prison.sentence("张三", "大巫", 20, "flood")
      :ok = Prison.release("张三")

      assert Prison.in_prison?("张三") == false
      assert Prison.detail("张三") == nil
    end

    test "重复释放不报错" do
      assert :ok = Prison.release("张三")
    end

    test "重新判处会覆盖旧刑期" do
      :ok = Prison.sentence("张三", "大巫", 20, "flood")
      :ok = Prison.sentence("张三", "大巫", 60, "rude")

      assert Prison.detail("张三").minutes == 60
      assert Prison.detail("张三").reason == "rude"
    end
  end

  describe "reasons/0" do
    test "白名单与 LPC 一致" do
      assert Prison.reasons() == ~w[flood copy rude rumor bug main]
    end
  end
end
