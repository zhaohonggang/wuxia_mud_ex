defmodule Kantele.World.LoaderInquiryStateTest do
  use ExUnit.Case, async: true

  test "parse_character 归一 inquiry_state 键并保留脚本 map" do
    data = %{
      name: "武修文",
      description: "",
      combat: %{},
      inquiry_state: %{huju_count: 20, beixin_count: 2},
      inquiries: %{
        铁护腕: %{kind: "give_item", item: "shaolin:huwan", count: "huju_count"}
      }
    }

    {_, npc} = Kantele.World.Loader.parse_character(%{id: "xiangyang"}, "wuxiuwen", data, %{})

    assert npc.meta.inquiry_state == %{"huju_count" => 20, "beixin_count" => 2}
    assert npc.meta.inquiries["铁护腕"]["kind"] == "give_item"
  end

  test "缺省 inquiry_state 为 %{}" do
    data = %{name: "路人", description: "", combat: %{}}

    {_, npc} = Kantele.World.Loader.parse_character(%{id: "test"}, "passerby", data, %{})

    assert npc.meta.inquiry_state == %{}
  end
end
