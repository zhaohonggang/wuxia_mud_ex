defmodule Kantele.Character.FamilyTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Family

  defp wudang do
    %{name: "武当派", master_id: "zhang sanfeng", master_name: "张三丰", generation: 0}
  end

  defp wudang_disciple do
    %{
      name: "武当派",
      master_id: "zhang sanfeng",
      master_name: "张三丰",
      generation: 1,
      title: "弟子",
      privs: 0
    }
  end

  defp emei, do: %{name: "峨嵋派", master_id: "miejue", master_name: "灭绝师太", generation: 0}

  test "is_apprentice_of?: 嫡传判断" do
    assert Family.is_apprentice_of?(wudang(), wudang_disciple())
    refute Family.is_apprentice_of?(wudang(), emei())
    refute Family.is_apprentice_of?(wudang(), %{})
  end

  test "is_apprentice_of?: 转世同门派也算" do
    my = wudang() |> Map.put(:reborn_family, "武当派")
    assert Family.is_apprentice_of?(my, %{name: "武当派"})
    assert Family.name(%{name: "武当派"}) == "武当派"
  end

  test "create_family: 私=-1 全权限" do
    %{name: name, generation: g, privs: p} = Family.create_family("桃花岛", 0, "岛主")
    assert name == "桃花岛"
    assert g == 0
    assert p == -1
  end

  test "recruit_apprentice: 正常收徒" do
    {:ok, fam, info} =
      Family.recruit_apprentice(wudang(), emei(), %{
        master_id: "zhang sanfeng",
        master_name: "张三丰",
        born_family: "没有"
      })

    assert info.inherit_title == false
    assert fam.name == "武当派"
    assert fam.generation == 1
    assert fam.master_id == "zhang sanfeng"
    assert fam.title == "弟子"
  end

  test "recruit_apprentice: 已是弟子 -> error" do
    assert Family.recruit_apprentice(wudang(), wudang_disciple()) == {:error, :already}
  end

  test "recruit_apprentice: 无门派 -> error" do
    assert Family.recruit_apprentice(%{}, emei()) == {:error, :no_family}
  end

  test "recruit_apprentice: 传人称号 (born_family != 没有)" do
    {:ok, fam, _} =
      Family.recruit_apprentice(wudang(), emei(), %{
        master_id: "zhang sanfeng",
        master_name: "张三丰",
        born_family: "武当"
      })

    assert fam.title == "传人"
  end
end
