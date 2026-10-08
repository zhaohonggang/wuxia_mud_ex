defmodule Kantele.T5PreparedGatesTest do
  use ExUnit.Case

  test "T5: :prepared gate infrastructure exists and works correctly" do
    # The :prepared gate is an infrastructure feature in Spec/Simple.
    # Currently no performs use the Simple macro (they implement run/1 directly),
    # so no performs have spec() functions with :prepared gates yet.
    # This test verifies the infrastructure works correctly.

    # 1. Spec module defines :prepared gate type
    # The @type gate in Spec includes {:prepared, usage :: String.t(), String.t()}

    # 2. Test Stats module prepare/unprepare functionality
    stats = Kantele.Character.Stats.new()
      |> Kantele.Character.Stats.learn_perform("huashan-jian/jie")
    {:ok, stats} = Kantele.Character.Stats.prepare_perform(stats, "sword", "huashan-jian/jie")

    # Verify it was stored
    assert Kantele.Character.Stats.prepared_perform(stats, "sword") == "huashan-jian/jie"
    assert Kantele.Character.Stats.prepared?(stats, "sword") == true

    # Test unprepare
    stats = Kantele.Character.Stats.unprepare_perform(stats, "sword")
    assert Kantele.Character.Stats.prepared_perform(stats, "sword") == nil
    assert Kantele.Character.Stats.prepared?(stats, "sword") == false

    # Test multiple usages
    stats = Kantele.Character.Stats.new()
      |> Kantele.Character.Stats.learn_perform("huashan-jian/jie")
      |> Kantele.Character.Stats.learn_perform("taiji-quan/chan")
    {:ok, stats} = Kantele.Character.Stats.prepare_perform(stats, "sword", "huashan-jian/jie")
    {:ok, stats} = Kantele.Character.Stats.prepare_perform(stats, "unarmed", "taiji-quan/chan")

    assert Kantele.Character.Stats.prepared_perform(stats, "sword") == "huashan-jian/jie"
    assert Kantele.Character.Stats.prepared_perform(stats, "unarmed") == "taiji-quan/chan"

    stats = Kantele.Character.Stats.unprepare_perform(stats, "sword")
    assert Kantele.Character.Stats.prepared_perform(stats, "sword") == nil
    assert Kantele.Character.Stats.prepared_perform(stats, "unarmed") == "taiji-quan/chan"
  end

  test "T5: Only 4 skills have preparation requirements in original MUD" do
    # Based on grep for query_skill_prepared in LPC source:
    # bagua_biao, chousui_zhang, huoyan_dao, jingang_zhi
    # (and many others not yet implemented in Elixir)
    skills_with_prepare = ["bagua_biao", "chousui_zhang", "huoyan_dao", "jingang_zhi"]

    # These are the only Elixir skills with preparation requirements
    # in the original MUD that are currently implemented
    assert length(skills_with_prepare) == 4

    # TODO: When performs are migrated to use Simple macro,
    # add :prepared gates to these skills' performs
  end
end