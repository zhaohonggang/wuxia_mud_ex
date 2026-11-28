defmodule Kantele.World.DuanYidengGrantGateTest do
  @moduledoc """
  #845 一灯大师 `yideng.c ask_skill2`「先天功乾阳剑气」定向测试。

  覆盖：全真教/段氏皇族双门派同门门、yiyang-zhi/xiantian-gong 两道技能存在门、
  `shen → force → max_neili → gongxian → 后天等级链` 原序，以及既有 lpc_kunlun 零回归。
  """

  use ExUnit.Case, async: true

  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @family_deny "施主与老衲素不相识，不知施主此话从何说起？\n"
  @yiyang_deny "你连一阳指诀都没学，还谈什么绝招可言？\n"
  @xiantian_deny "这招暂时不能传授于你，等你学会先天功再来找我吧。\n"
  @shen_deny "你的侠义正事还做得不够，这招老衲暂时还不能传你。\n"
  @force_deny "你内功的修为还不够，练高了再来吧。\n"
  @neili_deny "你的内力修为还不够，练高点再来吧。\n"
  @gongxian_deny "你的贡献值不够，这招先不忙传你。\n"
  @xiantian_level_deny "你的先天功功力还不够，练高了再说吧。\n"

  setup_all do
    world = Loader.load()
    yideng = Enum.find(world.characters, &(&1.name == "一灯大师")) || raise("一灯大师 not found")

    config = yideng.meta.inquiries["先天功乾阳剑气"] || raise("先天功乾阳剑气 inquiry not found")

    %{config: config, npc: %{family: "段氏皇族"}}
  end

  defp base_skills do
    %{
      "yiyang-zhi" => 280,
      "xiantian-gong" => 280,
      "force" => 500,
      "jingluo-xue" => 200
    }
  end

  defp player(opts) do
    %{
      family: Keyword.get(opts, :family, "段氏皇族"),
      shen: Keyword.get(opts, :shen, 50_000),
      gongxian: Keyword.get(opts, :gongxian, 3_000),
      max_neili: Keyword.get(opts, :max_neili, 5_000),
      skills: Keyword.get(opts, :skills, base_skills()),
      performs: Keyword.get(opts, :performs, MapSet.new())
    }
  end

  describe "UCL 回填" do
    test "先天功乾阳剑气切到 #845 独立门序并带双门派/双存在门配置", %{config: config} do
      assert config["gate_order"] == "lpc_duan_yideng"
      assert config["perform_id"] == "xiantian-gong/jian"
      assert config["allowed_families"] == ["全真教", "段氏皇族"]
      assert config["presence_skills"] == ["yiyang-zhi", "xiantian-gong"]
      assert config["presence_deny"]["yiyang-zhi"] == String.trim_trailing(@yiyang_deny)
      assert config["presence_deny"]["xiantian-gong"] == String.trim_trailing(@xiantian_deny)

      assert config["level_order"] == [
               "force",
               "max-neili",
               "xiantian-gong",
               "yiyang-zhi",
               "jingluo-xue"
             ]

      assert config["min_gongxian"] == 3_000
      assert config["cost_gongxian"] == 3_000
    end
  end

  describe "ask_skill2 原序" do
    test "全真教与段氏皇族弟子都可通过同门门", %{config: config, npc: npc} do
      for family <- ["全真教", "段氏皇族"] do
        assert {:ok, "xiantian-gong/jian", 3_000} =
                 SectMaster.inquiry_grant(player(family: family), npc, config)
      end
    end

    test "其余门派仍按 LPC 逐字拒绝", %{config: config, npc: npc} do
      assert {:error, @family_deny} = SectMaster.inquiry_grant(player(family: "武当派"), npc, config)
    end

    test "yiyang-zhi 未学时先拒，早于 xiantian-gong 存在门", %{config: config, npc: npc} do
      skills = base_skills() |> Map.put("yiyang-zhi", 0) |> Map.put("xiantian-gong", 0)

      assert {:error, @yiyang_deny} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end

    test "yiyang-zhi 已学但 xiantian-gong 未学：逐字拒绝", %{config: config, npc: npc} do
      skills = base_skills() |> Map.put("xiantian-gong", 0)

      assert {:error, @xiantian_deny} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end

    test "侠义门先于 force 与贡献门", %{config: config, npc: npc} do
      assert {:error, @shen_deny} =
               SectMaster.inquiry_grant(player(shen: 49_999, gongxian: 0), npc, config)
    end

    test "force 门先于贡献门", %{config: config, npc: npc} do
      skills = base_skills() |> Map.put("force", 499)

      assert {:error, @force_deny} =
               SectMaster.inquiry_grant(player(skills: skills, gongxian: 0), npc, config)
    end

    test "max_neili 门先于贡献门", %{config: config, npc: npc} do
      assert {:error, @neili_deny} =
               SectMaster.inquiry_grant(player(max_neili: 4_999, gongxian: 0), npc, config)
    end

    test "贡献门位于 max_neili 之后、后天等级链之前", %{config: config, npc: npc} do
      assert {:error, @gongxian_deny} =
               SectMaster.inquiry_grant(player(gongxian: 2_999), npc, config)
    end

    test "贡献足够后才进入 xiantian-gong 等级门", %{config: config, npc: npc} do
      skills = base_skills() |> Map.put("xiantian-gong", 279)

      assert {:error, @xiantian_level_deny} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end
  end

  describe "零回归" do
    test "旧 lpc_kunlun 配置仍只认单门派", %{config: config, npc: npc} do
      legacy =
        config
        |> Map.put("gate_order", "lpc_kunlun")
        |> Map.drop(["allowed_families", "presence_skills", "presence_deny"])

      assert {:error, @family_deny} = SectMaster.inquiry_grant(player(family: "全真教"), npc, legacy)
    end
  end
end
