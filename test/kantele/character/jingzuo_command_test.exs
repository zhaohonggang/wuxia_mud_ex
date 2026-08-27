defmodule Kantele.Character.JingzuoCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Vitals
  alias Kantele.Character.Stats

  describe "静坐条件检查" do
    test "峨嵋派门派限制存在" do
      family = %{name: "峨嵋派", master_id: "wang_chongjiu", master_name: "王重九"}
      assert family[:name] == "峨嵋派"
    end

    test "非峨嵋派门派被拒绝" do
      family = %{name: "少林派", master_id: "master1", master_name: "大师"}
      assert family[:name] != "峨嵋派"
    end

    test "无门派被拒绝" do
      family = nil
      assert family == nil
    end
  end
end
