defmodule Kantele.Character.PrepareCommandTest do
  use ExUnit.Case, async: true

  describe "prepare 拳术种类" do
    test "有效拳术种类列表" do
      valid = ["finger", "hand", "cuff", "claw", "strike", "unarmed"]

      for type <- valid do
        assert type in ["finger", "hand", "cuff", "claw", "strike", "unarmed"]
      end
    end

    test "无效种类被拒绝" do
      invalid = ["sword", "force", "dodge", "liuxin-jian"]

      for type <- invalid do
        refute type in ["finger", "hand", "cuff", "claw", "strike", "unarmed"]
      end
    end
  end
end
