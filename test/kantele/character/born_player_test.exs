defmodule Kantele.Character.BornPlayerTest do
  @moduledoc """
  BornPlayer 单元（纯函数）测试：对应 LPC `updated.c` 的 `born_player`（updated.c:344-445）。

  验证：硬性剔除集、wrath 剔除、属性 <20 剔除、随机赠 1–3 项、命中技能 +2 属性、
  以及授予列表镜像进 env[:special_skills]。
  """
  use ExUnit.Case, async: true

  alias Kalevala.Character
  alias Kantele.Character.BornPlayer
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats

  defp character(opts \\ []) do
    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      int: Keyword.get(opts, :int, 20),
      con: Keyword.get(opts, :con, 20),
      dex: Keyword.get(opts, :dex, 20),
      per: Keyword.get(opts, :per, 20)
    }

    %Character{
      id: "p1",
      name: "tester",
      pid: self(),
      room_id: "register:yanluodian",
      attributes: %{},
      meta: %PlayerMeta{stats: stats}
    }
  end

  describe "candidate_pool" do
    test "硬性剔除集 + wrath 始终不在候选池（新玩家 character 恒 nil）" do
      pool = character() |> BornPlayer.candidate_pool()

      for id <- ["guibian", "guimai", "jinshen", "piyi", "lighting", "qinzong", "wuxing", "shenyan", "tiandao", "herb", "wrach", "trick", "wrath"] do
        refute id in pool, "候选池不应含被剔除技能 #{id}"
      end

      # 这些是新玩家应当可获得的
      for id <- ["strength", "intellect", "constitution", "dexterity", "youth", "clever", "accuracy", "agile"] do
        assert id in pool, "候选池应含可获技能 #{id}"
      end
    end

    test "属性 <20 剔除对应技能（updated.c:376-397）" do
      pool =
        character(str: 10, int: 10, con: 10, dex: 10, per: 10)
        |> BornPlayer.candidate_pool()

      refute "strength" in pool
      refute "intellect" in pool
      refute "clever" in pool
      refute "constitution" in pool
      refute "dexterity" in pool
      refute "youth" in pool
    end

    test "属性 >=20 保留对应技能" do
      pool =
        character(str: 30, int: 30, con: 30, dex: 30, per: 30)
        |> BornPlayer.candidate_pool()

      assert "strength" in pool
      assert "intellect" in pool
      assert "clever" in pool
      assert "constitution" in pool
      assert "dexterity" in pool
      assert "youth" in pool
    end
  end

  describe "grant" do
    test "返回 1–3 项且均来自候选池" do
      c = character(str: 30, int: 30, con: 30, dex: 30, per: 30)
      pool = BornPlayer.candidate_pool(c)

      Enum.each(1..300, fn _ ->
        granted =
          c
          |> BornPlayer.grant()
          |> Map.get(:attributes)
          |> Map.get("special_skills", %{})
          |> Map.keys()

        assert length(granted) in 1..3
        Enum.each(granted, fn id -> assert id in pool end)
      end)
    end

    test "命中的先天特技各 +2 对应属性（updated.c:425-438）" do
      c = character(str: 20, int: 20, con: 20, dex: 20, per: 20)

      Enum.each(1..500, fn _ ->
        ch = BornPlayer.grant(c)
        granted = Map.keys(ch.attributes["special_skills"] || %{})

        if "strength" in granted, do: assert ch.meta.stats.str == 22
        if "intellect" in granted, do: assert ch.meta.stats.int == 22
        if "constitution" in granted, do: assert ch.meta.stats.con == 22
        if "dexterity" in granted, do: assert ch.meta.stats.dex == 22
        # youth/clever 命中不触发 +2
        assert ch.meta.stats.per == 20
      end)
    end

    test "授予列表镜像进 meta.env[:special_skills]" do
      c = character(str: 30, int: 30, con: 30, dex: 30, per: 30)
      ch = BornPlayer.grant(c)
      granted = Map.keys(ch.attributes["special_skills"] || %{})
      assert Enum.sort(ch.meta.env[:special_skills]) == Enum.sort(granted)
    end
  end
end
