defmodule Kantele.World.ZhenyuanFamilyExceptionTest do
  @moduledoc """
  #835 王维扬天刀八势 / zhenyuan.h 的商家堡例外。

  收徒侧 permit_recruit 放行商家堡或商剑鸣弟子；授绝招侧 ask_skill6 则
  「商家堡」先过同门门、再吃专属拒绝。两侧语义相反，必须分别验证。
  """

  use ExUnit.Case, async: true

  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @outsider_deny "大侠和本镖局素无来往，何出此言？\n"
  @shangjia_deny "你虽然是商家堡的弟子，但没有你师傅同意我也不能传你这招！\n"
  @other_family_deny "不妥，不妥！你已经有师承了。\n"
  @maxed "你不是已经学会了吗？怎么，又给忘记了？\n"
  @neili_deny "你的内力修为不足，施展不出这招，等你内力有所攀升后再来找我吧。\n"

  setup_all do
    world = Loader.load()

    npc =
      Enum.find(world.characters, fn character ->
        character.name == "王维扬" and character.room_id == "beijing:shufang"
      end) || raise "王维扬 not found"

    %{apprentice: npc.meta.apprentice, grant: Map.fetch!(npc.meta.inquiries, "天刀八势")}
  end

  defp recruit_gate(config) do
    # 只隔离 permit_recruit 分支；后续 int/con/exp/skill 门由既有测试覆盖。
    Map.merge(config, %{min_int_con_both: nil, min_exp: 0, min_skills: %{}})
  end

  defp student(opts \\ []) do
    %{
      meta: %{
        family: Keyword.get(opts, :family, %{}),
        stats: %{combat_exp: 1_000_000, shen: 0, skills: %{}},
        env: %{}
      }
    }
  end

  defp npc_stats, do: %{family: "八卦门"}

  defp player(opts \\ []) do
    performs =
      if Keyword.get(opts, :known?, false) do
        MapSet.new(["bagua-dao/tian"])
      else
        MapSet.new()
      end

    %{
      family: Keyword.get(opts, :family, "八卦门"),
      performs: performs,
      skills:
        Keyword.get(opts, :skills, %{
          "bagua-dao" => 250,
          "wai-bagua" => 250,
          "nei-bagua" => 250
        }),
      gongxian: Keyword.get(opts, :gongxian, 3_000),
      max_neili: Keyword.get(opts, :max_neili, 4_000)
    }
  end

  describe "UCL 配置" do
    test "收徒侧落商家堡/商剑鸣双例外", ctx do
      assert ctx.apprentice.allow_families == ["商家堡"]
      assert ctx.apprentice.allow_master_name == "商剑鸣"
    end

    test "天刀八势改走专用门序并落逐字例外文案", ctx do
      assert Map.fetch!(ctx.grant, "gate_order") == "lpc_zhenyuan_tian"
      assert Map.fetch!(ctx.grant, "family_exception") == "商家堡"

      assert Map.fetch!(ctx.grant, "family_exception_deny") ==
               String.trim_trailing(@shangjia_deny)
    end
  end

  describe "收徒侧 permit_recruit（zhenyuan.h:17-24）" do
    test "商家堡弟子放行", ctx do
      assert :ok =
               SectMaster.recruit_gate?(
                 nil,
                 student(family: %{name: "商家堡", master_name: "商老太"}),
                 recruit_gate(ctx.apprentice)
               )
    end

    test "他派但师父是商剑鸣也放行", ctx do
      assert :ok =
               SectMaster.recruit_gate?(
                 nil,
                 student(family: %{name: "少林派", master_name: "商剑鸣"}),
                 recruit_gate(ctx.apprentice)
               )
    end

    test "他派且非商剑鸣弟子仍按 LPC 原文拒绝", ctx do
      assert {:error, @other_family_deny} =
               SectMaster.recruit_gate?(
                 nil,
                 student(family: %{name: "少林派", master_name: "玄慈"}),
                 recruit_gate(ctx.apprentice)
               )
    end

    test "无门派玩家不被他派门拦截", ctx do
      assert :ok = SectMaster.recruit_gate?(nil, student(), recruit_gate(ctx.apprentice))
    end
  end

  describe "授绝招侧 ask_skill6（wangweiyang.c:412-506）" do
    test "商家堡弟子吃专属拒绝，而非素无来往文案", ctx do
      assert {:error, @shangjia_deny} =
               SectMaster.inquiry_grant(player(family: "商家堡"), npc_stats(), ctx.grant)
    end

    test "商家堡专属拒绝优先于技能存在与贡献门", ctx do
      low = player(family: "商家堡", skills: %{}, gongxian: 0, max_neili: 0)

      assert {:error, @shangjia_deny} = SectMaster.inquiry_grant(low, npc_stats(), ctx.grant)
    end

    test "其余门派仍吃素无来往文案", ctx do
      assert {:error, @outsider_deny} =
               SectMaster.inquiry_grant(player(family: "少林派"), npc_stats(), ctx.grant)
    end

    test "已学玩家先吃已会文案（maxed 先于 family 门）", ctx do
      known = player(family: "商家堡", known?: true)

      assert {:error, @maxed} = SectMaster.inquiry_grant(known, npc_stats(), ctx.grant)
    end

    test "同门且全部门槛达标 → 授予天刀八势，贡献扣 2400", ctx do
      assert {:ok, "bagua-dao/tian", 2400} =
               SectMaster.inquiry_grant(player(), npc_stats(), ctx.grant)
    end

    test "专用门序保留原有序等级链（max_neili 文案不丢）", ctx do
      low_neili = player(max_neili: 100)

      assert {:error, @neili_deny} = SectMaster.inquiry_grant(low_neili, npc_stats(), ctx.grant)
    end

    test "旧 lpc_kunlun 门序仍把商家堡当外人，证明改动是 opt-in", ctx do
      legacy = Map.put(ctx.grant, "gate_order", "lpc_kunlun")

      assert {:error, @outsider_deny} =
               SectMaster.inquiry_grant(player(family: "商家堡"), npc_stats(), legacy)
    end
  end
end
