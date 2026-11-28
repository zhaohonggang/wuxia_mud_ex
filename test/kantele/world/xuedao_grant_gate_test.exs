defmodule Kantele.World.XuedaoGrantGateTest do
  @moduledoc """
  #795 血刀门宝象/胜谛 ask_skill1 定向测试。

  覆盖：UCL `kind = "sect_master_grant"` + `gate_order = "lpc_xuedao"` 路由、
  LPC 原序（已会 → 同门 → 技能存在 → 贡献 → 杀气负上界 → force → max_neili
  → 本招刀法等级）、force/本招等级的 level_deny map 逐字文案，以及
  msg_one/emotes/npc_say 演示文案字段（SectMasterGrant 渲染消费）。
  """

  use ExUnit.Case, async: true

  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @family_deny "你又不是我血刀门的，再罗嗦我宰了你！"
  @skill_deny_honglian "你连红莲刀法都没学，还罗嗦什么？"
  @skill_deny_xueshan "你连雪山刀法都没学，还罗嗦什么？"
  @gongxian_deny "老祖说了，咋们的绝技不传无功之人。"
  @shen_deny "你这样心慈手软，就算学会这招又有什么用？"
  @force_deny "你的内功修为实在太差，快去多练练再来。"
  @honglian_level_deny "等你把红莲刀法练熟了再来找我吧。"
  @xueshan_level_deny "等你把雪山刀法练熟了再来找我吧。"
  @neili_deny "你的内力差成这样，居然还好意思来找我？"
  @maxed "我不是都已经教过你了吗？"

  setup_all do
    world = Loader.load()

    baoxiang =
      Enum.find(world.characters, &(&1.name == "宝象")) ||
        Enum.find(world.characters, fn c ->
          c.meta && is_map(c.meta.inquiries) && Map.has_key?(c.meta.inquiries || %{}, "流星火雨")
        end) || raise("宝象 not found")

    shengdi =
      Enum.find(world.characters, &(&1.name == "胜谛")) ||
        Enum.find(world.characters, fn c ->
          c.meta && is_map(c.meta.inquiries) && Map.has_key?(c.meta.inquiries || %{}, "冰河开封")
        end) || raise("胜谛 not found")

    %{
      huo: baoxiang.meta.inquiries["流星火雨"] || raise("流星火雨 not found"),
      kai: shengdi.meta.inquiries["冰河开封"] || raise("冰河开封 not found"),
      npc: %{family: "血刀门"}
    }
  end

  defp player(opts \\ []) do
    %{
      family: Keyword.get(opts, :family, "血刀门"),
      shen: Keyword.get(opts, :shen, -50_000),
      gongxian: Keyword.get(opts, :gongxian, 3_000),
      max_neili: Keyword.get(opts, :max_neili, 5_000),
      skills:
        Keyword.get(
          opts,
          :skills,
          %{"force" => 500, "honglian-dao" => 200, "xueshan-dao" => 200, "blade" => 200}
        ),
      performs: Keyword.get(opts, :performs, MapSet.new())
    }
  end

  describe "UCL 回填与路由" do
    test "两块都切到 sect_master_grant + lpc_xuedao 门序", %{huo: huo, kai: kai} do
      for config <- [huo, kai] do
        assert config["kind"] == "sect_master_grant"
        assert config["gate_order"] == "lpc_xuedao"
      end

      assert huo["perform_id"] == "honglian-dao/huo"
      assert huo["min_gongxian"] == 80
      assert huo["max_shen"] == -8_000
      assert huo["min_max_neili"] == 800
      # loader 对 inquiries 子键做 `_`→`-` 归一（min_levels/level_deny 同规）
      assert huo["min_levels"] == %{"force" => 120, "honglian-dao" => 80}
      assert huo["cost_gongxian"] == 80

      assert kai["perform_id"] == "xueshan-dao/kai"
      assert kai["min_gongxian"] == 50
      assert kai["max_shen"] == -3_000
      assert kai["min_max_neili"] == 600
      assert kai["min_levels"] == %{"force" => 100, "xueshan-dao" => 80}
      assert kai["cost_gongxian"] == 50
    end

    test "演示文案字段逐字（msg_one/emotes/npc_say/learned）", %{huo: huo, kai: kai} do
      assert huo["msg_one"] =~ "狞笑数声"
      assert huo["msg_one"] =~ "{npc}" and huo["msg_one"] =~ "{name}"
      assert huo["emotes"] == "bored"
      assert huo["npc_say"] == "好了，好了。你自己去练吧。"
      assert huo["learned"] == "你学会了「流星火雨」。"

      assert kai["msg_one"] =~ "微微一笑"
      assert kai["emotes"] == "nod"
      assert kai["npc_say"] == "招数便是如此，你看懂了多少？"
      assert kai["learned"] == "你学会了「冰河开封」。"
    end

    test "level_deny 为 map 且两条文案逐字", %{huo: huo, kai: kai} do
      assert huo["level_deny"]["force"] == @force_deny
      assert huo["level_deny"]["honglian-dao"] == @honglian_level_deny
      assert kai["level_deny"]["force"] == @force_deny
      assert kai["level_deny"]["xueshan-dao"] == @xueshan_level_deny
    end
  end

  describe "宝象「流星火雨」LPC 原序" do
    test "已会则拒绝（maxed）", %{huo: config, npc: npc} do
      player = player(performs: MapSet.new(["honglian-dao/huo"]))

      assert {:error, @maxed} = SectMaster.inquiry_grant(player, npc, config)
    end

    test "非本门拒绝", %{huo: config, npc: npc} do
      assert {:error, @family_deny} =
               SectMaster.inquiry_grant(player(family: "武当派"), npc, config)
    end

    test "本招技能未学拒绝（早于贡献门）", %{huo: config, npc: npc} do
      skills = player()[:skills] |> Map.put("honglian-dao", 0)

      assert {:error, @skill_deny_honglian} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end

    test "贡献不足拒绝（早于杀气门）", %{huo: config, npc: npc} do
      # 同时贡献不足 + 杀气太软：LPC 先报贡献（gongxian 在 shen 之前）
      assert {:error, @gongxian_deny} =
               SectMaster.inquiry_grant(player(gongxian: 10, shen: 0), npc, config)
    end

    test "杀气太软拒绝", %{huo: config, npc: npc} do
      assert {:error, @shen_deny} = SectMaster.inquiry_grant(player(shen: -1_000), npc, config)
    end

    test "force 不足时报 force 文案（早于 max_neili 门）", %{huo: config, npc: npc} do
      # 同时 force=60(<120) 与 max_neili=100(<800)：LPC 先报内功修为
      skills = player()[:skills] |> Map.put("force", 60)

      assert {:error, @force_deny} =
               SectMaster.inquiry_grant(player(skills: skills, max_neili: 100), npc, config)
    end

    test "max_neili 不足拒绝", %{huo: config, npc: npc} do
      assert {:error, @neili_deny} =
               SectMaster.inquiry_grant(player(max_neili: 799), npc, config)
    end

    test "本招刀法等级不足报逐字文案", %{huo: config, npc: npc} do
      skills = player()[:skills] |> Map.put("honglian-dao", 79)

      assert {:error, @honglian_level_deny} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end

    test "全部满足返回 perform_id 与贡献扣除", %{huo: config, npc: npc} do
      assert {:ok, "honglian-dao/huo", 80} = SectMaster.inquiry_grant(player(), npc, config)
    end
  end

  describe "胜谛「冰河开封」LPC 原序" do
    test "本招技能未学拒绝", %{kai: config, npc: npc} do
      skills = player()[:skills] |> Map.put("xueshan-dao", 0)

      assert {:error, @skill_deny_xueshan} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end

    test "本招刀法等级不足报逐字文案", %{kai: config, npc: npc} do
      skills = player()[:skills] |> Map.put("xueshan-dao", 79)

      assert {:error, @xueshan_level_deny} =
               SectMaster.inquiry_grant(player(skills: skills), npc, config)
    end

    test "全部满足返回 perform_id 与贡献扣除", %{kai: config, npc: npc} do
      assert {:ok, "xueshan-dao/kai", 50} = SectMaster.inquiry_grant(player(), npc, config)
    end
  end
end
