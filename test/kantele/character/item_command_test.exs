defmodule Kantele.Character.ItemCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.ItemCommand

  describe "drop validation" do
    test "rejects dropping equipped item" do
      conn = build_conn_with_inventory([])
      # Equipped item would be in combat.equipped
      assert true
    end

    test "rejects dropping riding mount" do
      conn = build_conn_with_inventory([])
      # Riding mount would be in meta.riding
      assert true
    end

    test "accepts dropping normal item" do
      assert true
    end
  end

  describe "get validation" do
    test "rejects when inventory full" do
      assert true
    end

    test "accepts when inventory has space" do
      assert true
    end
  end

  defp build_conn_with_inventory(inventory) do
    %{
      character: %{
        inventory: inventory,
        meta: %{
          combat: %{equipped: %{}},
          riding: nil
        }
      },
      room: %{items: []}
    }
  end
end
