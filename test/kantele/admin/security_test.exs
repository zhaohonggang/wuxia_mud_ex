defmodule Kantele.Admin.SecurityTest do
  @moduledoc """
  Kantele.Admin.Security 授权注册表的单元行为测试（不依赖 DB）。
  """
  use ExUnit.Case, async: false

  alias Kantele.Admin.Security

  setup do
    Security.ensure!()
    Security.clear("张三")
    Security.clear("李四")
    :ok
  end

  describe "grant / granted?" do
    test "授予后查询为真，且去重" do
      assert Security.granted?("张三", "clone") == false

      :ok = Security.grant("张三", "clone")
      assert Security.granted?("张三", "clone") == true

      :ok = Security.grant("张三", "clone")
      assert Security.list_for("张三") == ["clone"]
    end

    test "不同玩家互不影响" do
      :ok = Security.grant("张三", "clone")
      :ok = Security.grant("李四", "smash")

      assert Security.granted?("张三", "clone") == true
      assert Security.granted?("张三", "smash") == false
      assert Security.granted?("李四", "smash") == true
    end

    test "多命令授予保留全部" do
      :ok = Security.grant("张三", "clone")
      :ok = Security.grant("张三", "to")
      :ok = Security.grant("张三", "clone")

      assert Enum.sort(Security.list_for("张三")) == ["clone", "to"]
    end
  end

  describe "revoke" do
    test "撤销已授予的命令后查询为假" do
      :ok = Security.grant("张三", "clone")
      :ok = Security.grant("张三", "to")

      :ok = Security.revoke("张三", "clone")
      assert Security.granted?("张三", "clone") == false
      assert Security.granted?("张三", "to") == true
    end

    test "撤销不存在的命令不报错" do
      :ok = Security.revoke("张三", "nonexistent")
      assert Security.granted?("张三", "nonexistent") == false
    end
  end

  describe "clear" do
    test "清空某玩家全部授权" do
      :ok = Security.grant("张三", "clone")
      :ok = Security.grant("张三", "to")
      :ok = Security.clear("张三")

      assert Security.list_for("张三") == []
    end
  end
end
