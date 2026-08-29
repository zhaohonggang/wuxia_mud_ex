defmodule ConditionSmokeTest do
  @cnd_continue 1

  def run do
    ExUnit.start()
    Code.require_file("condition.ex", __DIR__)

    alias ExKantele.World.Condition

    IO.puts("Running Condition smoke tests...")

    run_test("init_feature", fn ->
      state = Condition.init_feature(%{})
      check(state.condition.conditions == %{})
      check(state.condition.applyers == %{})
    end)

    run_test("apply_condition / query_condition", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10, duration: 100})
      check(Condition.query_condition(state, "poison") == %{level: 10, duration: 100})
    end)

    run_test("multiple conditions", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10, duration: 100})
      state = Condition.apply_condition(state, "drunk", %{level: 5})
      check(Condition.query_condition(state, "drunk") == %{level: 5})
      check(map_size(Condition.query_condition(state, nil)) == 2)
    end)

    run_test("query_condition nil returns all", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = Condition.apply_condition(state, "drunk", %{level: 5})
      conds = Condition.query_condition(state, nil)
      check(Map.has_key?(conds, "poison"))
      check(Map.has_key?(conds, "drunk"))
    end)

    run_test("clear_condition single", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = Condition.apply_condition(state, "drunk", %{level: 5})
      state = Condition.clear_condition(state, "poison")
      check(Condition.query_condition(state, "poison") == nil)
      check(Condition.query_condition(state, "drunk") == %{level: 5})
    end)

    run_test("clear_condition all", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = Condition.clear_condition(state, nil)
      check(Condition.query_condition(state, nil) == %{})
    end)

    run_test("applyer tracking", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      check(Condition.last_applyer_name(state, "poison") == "Attacker")
      check(Condition.last_applyer_id(state, "poison") == "player:attacker")
    end)

    run_test("update_condition clears unknown condition", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "unknown_cnd", %{level: 1})
      state = Condition.update_condition(state)
      check(Condition.query_condition(state, "unknown_cnd") == nil)
    end)

    run_test("update_condition continues known condition", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10, duration: 100})
      state = Condition.update_condition(state)
      check(Condition.query_condition(state, "poison") == %{level: 10, duration: 100})
    end)

    run_test("dispel_condition", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      check(Condition.dispel_condition(state, "poison") == 1)
      check(Condition.query_condition(state, "poison") == nil)
    end)

    run_test("affect_by", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      check(Condition.affect_by(state, "poison") == 1)
    end)

    run_test("affect_by blocked by piyi", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = put_in(state, [:special_skills], ["piyi"])
      check(Condition.affect_by(state, "poison") == 0)
    end)

    run_test("clear_condition preserves other conditions", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = Condition.apply_condition(state, "drunk", %{level: 5})
      state = Condition.clear_condition(state, "poison")
      check(Condition.query_condition(state, "poison") == nil)
      check(Condition.query_condition(state, "drunk") == %{level: 5})
    end)

    run_test("last_applyer cleared with condition", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = Condition.clear_condition(state, "poison")
      check(Condition.last_applyer_name(state, "poison") == nil)
      check(Condition.last_applyer_id(state, "poison") == nil)
    end)

    run_test("update_condition sets last_applyer", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "poison", %{level: 10})
      state = Condition.update_condition(state)
      check(Condition.last_applyer_name(state, "poison") == "Attacker")
      check(Condition.last_applyer_id(state, "poison") == "player:attacker")
    end)

    run_test("update_condition clears expired condition (flag 0)", fn ->
      state = init_state()
      state = Condition.apply_condition(state, "expire_test", %{level: 10})
      state = Condition.update_condition(state)
      check(Condition.query_condition(state, "expire_test") == nil)
    end)

    IO.puts("\n✅ All smoke tests passed!")
  end

  defp run_test(name, fun) do
    try do
      fun.()
      IO.puts("✓ #{name}")
      :ok
    catch
      kind, reason ->
        IO.puts("✗ #{name}: #{kind} - #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp check(condition) do
    unless condition do
      raise "Assertion failed"
    end
  end

  # --- Mocks ---

  defmodule MockConditionDaemon do
    def get("poison"), do: MockCndDaemon
    def get("drunk"), do: MockCndDaemon
    def get("expire_test"), do: MockExpireDaemon
    def get(_), do: nil
  end

  defmodule MockCndDaemon do
    @cnd_continue 1
    def update(_cnd, _state, info) do
      {@cnd_continue, info}
    end
    def dispel(_cnd, _state, _info), do: 1
    def do_effect(_cnd, _state, cnd, _para), do: 1
  end

  defmodule MockExpireDaemon do
    def update(_cnd, _state, _info), do: {0, nil}
    def dispel(_cnd, _state, _info), do: 1
    def do_effect(_cnd, _state, cnd, _para), do: 1
  end

  defmodule MockConditionDaemon do
    def get("poison"), do: MockCndDaemon
    def get("drunk"), do: MockCndDaemon
    def get("expire_test"), do: MockExpireDaemon
    def get(_), do: nil
  end

  def get_cnd_object(cnd), do: MockConditionDaemon.get(cnd)

  # Mock Player functions
  def this_player(), do: player_stub("player:attacker", "Attacker")
  def this_object(), do: player_stub("player:victim", "Victim")
  def id(%{id: id}), do: id
  def name(%{name: name}, _flag), do: name
  def is_player?(%{is_player: true}), do: true
  def is_player?(_), do: false
  def set_heart_beat(state, _enabled), do: state
  def get_temp(_state, _key), do: nil
  def has_special_skill?(_state, _skill), do: false

  defp player_stub(id, name) do
    %{id: id, name: name, is_player: true}
  end

  def init_state do
    %{
      condition: %{
        conditions: %{},
        applyers: %{},
        last_applyer_name: nil,
        last_applyer_id: nil
      }
    }
  end
end

ExUnit.start()
Code.require_file("condition.ex", __DIR__)
ConditionSmokeTest.run()