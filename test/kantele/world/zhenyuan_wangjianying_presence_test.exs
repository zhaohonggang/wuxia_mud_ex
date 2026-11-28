defmodule Kantele.World.ZhenyuanWangjianyingPresenceTest do
  @moduledoc """
  #837 王剑英 ask_skill1/2 双技能存在门逐字文案。

  LPC `wangjianying.c:136-149` / `190-203` 对两招都先查 bagua-zhang < 1
  再查 bagua-biao < 1，且两句「没学」文案不同。旧 Ex 只有单一 `skill`
  门，次级技能缺失会落到「练得不到家」。本测试锁定 opt-in
  `presence_skills` / `presence_deny` 的逐条顺序与未配置时的旧行为。
  """

  use ExUnit.Case, async: true

  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @zhang_missing "你连八卦掌都没学，谈什么绝招？\n"
  @biao_missing "你连八卦镖都没学，谈什么绝招？\n"
  @gongxian_deny "你为镖局出力不够，这招我暂时不忙传你。\n"
  @zhang_low "你的八卦掌还练得不到家，自己下去练练再来吧！\n"
  @biao_low "你的八卦镖还练得不到家，自己下去练练再来吧！\n"
  @force_low "嗯，你的镖掌都已经娴熟了，但是切记内功火候是基础，这可半点马虎不得。\n"
  @family_deny "大侠和本镖局素无来往，何出此言？\n"
  @maxed_zhang "该说的我都说完了，还有什么不明白就自己下去练！\n"
  @maxed_biao "嗯？这招不是已经教过你了吗？\n"
  @presence_deny %{
    "bagua-zhang" => "你连八卦掌都没学，谈什么绝招？",
    "bagua-biao" => "你连八卦镖都没学，谈什么绝招？"
  }

  @grants [
    {"掌中夹镖", "bagua-zhang/jia", @maxed_zhang, 150},
    {"镖中现掌", "bagua-biao/xian", @maxed_biao, 200}
  ]

  setup_all do
    world = Loader.load()

    npc =
      Enum.find(world.characters, fn character ->
        Enum.any?(character.meta.aliases || [], &(&1 == "wang jianying"))
      end) || raise "王剑英 not found"

    grants =
      Map.new(@grants, fn {name, _perform, _maxed, _force} ->
        {name, Map.fetch!(npc.meta.inquiries, name)}
      end)

    %{npc: npc, grants: grants}
  end

  defp npc_stats, do: %{family: "八卦门"}

  defp player(opts) do
    known = Keyword.get(opts, :known, false)
    perform_id = Keyword.get(opts, :perform_id)

    performs =
      if known and is_binary(perform_id) do
        MapSet.new([perform_id])
      else
        MapSet.new()
      end

    skills =
      Keyword.get(opts, :skills, %{"bagua-zhang" => 120, "bagua-biao" => 120})
      |> Map.put("force", Keyword.get(opts, :force, 200))

    %{
      family: Keyword.get(opts, :family, "八卦门"),
      performs: performs,
      skills: skills,
      gongxian: Keyword.get(opts, :gongxian, 400)
    }
  end

  defp grant(ctx, name), do: Map.fetch!(ctx.grants, name)

  describe "UCL 配置" do
    for {name, _perform, _maxed, _force} <- @grants do
      test "#{name} 落有序双技能存在门与逐字未学文案", ctx do
        config = grant(ctx, unquote(name))

        assert Map.fetch!(config, "presence_skills") == ["bagua-zhang", "bagua-biao"]
        assert Map.fetch!(config, "presence_deny") == @presence_deny
      end
    end
  end

  describe "ask_skill1/2 原始门序（wangjianying.c）" do
    for {name, perform_id, maxed, force_min} <- @grants do
      test "#{name}：八卦掌未学先于八卦镖未学", ctx do
        config = grant(ctx, unquote(name))

        assert {:error, @zhang_missing} =
                 SectMaster.inquiry_grant(
                   player(skills: %{}),
                   npc_stats(),
                   config
                 )
      end

      test "#{name}：八卦掌已学但八卦镖未学，命中专属文案", ctx do
        config = grant(ctx, unquote(name))

        assert {:error, @biao_missing} =
                 SectMaster.inquiry_grant(
                   player(skills: %{"bagua-zhang" => 120}),
                   npc_stats(),
                   config
                 )
      end

      test "#{name}：已会先于同门与技能门", ctx do
        config = grant(ctx, unquote(name))

        assert {:error, unquote(maxed)} =
                 SectMaster.inquiry_grant(
                   player(
                     known: true,
                     perform_id: unquote(perform_id),
                     family: "星宿派",
                     skills: %{}
                   ),
                   npc_stats(),
                   config
                 )
      end

      test "#{name}：同门门先于双技能存在门", ctx do
        config = grant(ctx, unquote(name))

        assert {:error, @family_deny} =
                 SectMaster.inquiry_grant(
                   player(family: "星宿派", skills: %{}),
                   npc_stats(),
                   config
                 )
      end

      test "#{name}：技能存在后先查贡献，再查有序等级", ctx do
        config = grant(ctx, unquote(name))

        assert {:error, @gongxian_deny} =
                 SectMaster.inquiry_grant(
                   player(gongxian: 399, skills: %{"bagua-zhang" => 1, "bagua-biao" => 1}),
                   npc_stats(),
                   config
                 )

        assert {:error, @zhang_low} =
                 SectMaster.inquiry_grant(
                   player(skills: %{"bagua-zhang" => 119, "bagua-biao" => 120}),
                   npc_stats(),
                   config
                 )

        assert {:error, @biao_low} =
                 SectMaster.inquiry_grant(
                   player(skills: %{"bagua-zhang" => 120, "bagua-biao" => 119}),
                   npc_stats(),
                   config
                 )

        assert {:error, @force_low} =
                 SectMaster.inquiry_grant(
                   player(
                     skills: %{"bagua-zhang" => 120, "bagua-biao" => 120},
                     force: unquote(force_min) - 1
                   ),
                   npc_stats(),
                   config
                 )
      end

      test "#{name}：全部门槛通过后授予绝招并记贡献代价", ctx do
        config = grant(ctx, unquote(name))

        assert SectMaster.inquiry_grant(
                 player(skills: %{"bagua-zhang" => 120, "bagua-biao" => 120}),
                 npc_stats(),
                 config
               ) == {:ok, unquote(perform_id), 400}
      end

      test "#{name}：未配置 presence 字段时保持旧门（零回归）", ctx do
        legacy =
          grant(ctx, unquote(name))
          |> Map.drop(["presence_skills", "presence_deny"])

        # 旧引擎只查主技能 bagua-zhang；次级技能 0 落到 120 等级门槛，
        # 而不是新的「你连八卦镖都没学」。
        assert {:error, @biao_low} =
                 SectMaster.inquiry_grant(
                   player(skills: %{"bagua-zhang" => 120, "bagua-biao" => 0}),
                   npc_stats(),
                   legacy
                 )
      end
    end
  end
end
