defmodule Kantele.World.MurongTeachingTest do
  @moduledoc """
  #763 慕容派教学门控补完定向测试（LPC kungfu/class/murong/*.c）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name, room) do
    Enum.find(world.characters, fn c -> c.name == name and c.room_id == room end)
  end

  defp student(shen, exp, skills, born \\ "慕容世家") do
    %{
      meta: %{
        stats: %Stats{shen: shen, combat_exp: exp, skills: skills, gongxian: 0},
        env: %{born_family: born}
      }
    }
  end

  describe "UCL 字段（Loader 归一后）" do
    test "慕容复/慕容博：permit_recruit 三句 + born_family + 负神上界 + 有序技能门", %{world: world} do
      for name <- ["慕容复", "慕容博"] do
        ob = npc(world, name, if(name == "慕容复", do: "yanziwu:shuiyun", else: "yanziwu:canheju"))
        assert ob, "#{name} 应在 yanziwu:canheju"
        g = ob.meta.apprentice
        assert g.family == "慕容世家"
        assert g.permit_recruit == true
        assert g.required_born_family == "慕容世家"
        assert g.born_family_deny == "你不是我们慕容家的人，师徒就免了吧。"
        assert g.betray_sect_deny == "你吃里爬外，反复无常，叫我如何收你？"
        assert g.other_family_deny == "你既然已经离家拜师，又跑回来作甚？"
      end

      fu = npc(world, "慕容复", "yanziwu:shuiyun").meta.apprentice
      assert fu.max_shen == 0
      assert fu.max_shen_deny == "我慕容世家向来不和你们这些所谓正道人士交往。你还是请回吧！"
      assert fu.accept_msg == "今日我就暂且收下你，日后定须刻苦练武，光复大燕。"

      bo = npc(world, "慕容博", "yanziwu:canheju").meta.apprentice
      assert bo.max_shen == -36_000
      assert bo.min_exp == 500_000
      assert bo.min_exp_deny == "你现在经验尚浅，还是多在江湖上走走吧。"

      assert bo.min_skills == %{
               "douzhuan-xingyi" => 130,
               "murong-xinfa" => 120,
               "dodge" => 200
             }

      assert bo.recruit_skill_order == ["douzhuan-xingyi", "murong-xinfa", "dodge"]
      assert bo.min_skills_deny["dodge"] == "我慕容世家武功需配合灵巧的身法。你是否还应该在轻功修为上多下点功夫？"
      assert bo.accept_msg == "慕容博大喜：我们慕容家真是英才迭出，复国有望啊！"
    end

    test "慕容博 no_teach 24 项 + coagents/战斗闲聊", %{world: world} do
      bo = npc(world, "慕容博", "yanziwu:canheju")
      assert map_size(bo.meta.teach.no_teach_deny) == 23
      assert bo.meta.teach.no_teach_deny["canhe-zhi"] =~ "你参合指火候还不够"
      assert bo.meta.chat_chance_combat == 120
      assert "finger.canhe" in bo.meta.chat_msg_combat

      fu = npc(world, "慕容复", "yanziwu:shuiyun")
      assert hd(fu.meta.coagents)["id"] == "murong bo"
      assert hd(fu.meta.coagents)["startroom"] == "yanziwu:canheju"
      assert fu.meta.chat_chance_combat == 120
      assert "blade.feng" in fu.meta.chat_msg_combat
    end

    test "慕容龙城 绝技/绝招/风雨交加 三键同指 ask_me grant", %{world: world} do
      lc = npc(world, "慕容龙城", "guanwai:huandi1")

      assert lc

      for key <- ["绝技", "绝招", "风雨交加"] do
        cfg = lc.meta.inquiries[key]
        assert is_map(cfg), "#{key} 应为 grant map"
        assert cfg["perform_id"] == "longcheng-shendao/fengyu"
        assert cfg["kind"] == "sect_master_grant"
      end

      refute String.contains?(inspect(lc.meta.inquiries), "unimplemented")
    end
  end

  describe "收徒门序（真实 UCL 配置）" do
    test "born_family 硬门先于负神/经验/技能", %{world: world} do
      fu = npc(world, "慕容复", "yanziwu:shuiyun").meta.apprentice
      bo = npc(world, "慕容博", "yanziwu:canheju").meta.apprentice

      assert {:error, "你不是我们慕容家的人，师徒就免了吧。\n"} =
               SectMaster.recruit_gate?(nil, student(0, 0, %{}, "段氏皇族"), fu)

      assert {:error, "你不是我们慕容家的人，师徒就免了吧。\n"} =
               SectMaster.recruit_gate?(nil, student(-50_000, 500_000, %{}, "段氏皇族"), bo)
    end

    test "慕容复/慕容博负神上界 + 慕容博经验先于技能", %{world: world} do
      fu = npc(world, "慕容复", "yanziwu:shuiyun").meta.apprentice
      bo = npc(world, "慕容博", "yanziwu:canheju").meta.apprentice

      assert {:error, "我慕容世家向来不和你们这些所谓正道人士交往。你还是请回吧！\n"} =
               SectMaster.recruit_gate?(nil, student(1, 0, %{}), fu)

      assert :ok = SectMaster.recruit_gate?(nil, student(-1, 0, %{}), fu)

      assert {:error, "我慕容博向来不与你们这些所谓正道人士交往。你还是请回吧！\n"} =
               SectMaster.recruit_gate?(nil, student(-35_999, 500_000, %{}), bo)

      # 经验不足 + 技能全无 → 先报经验（LPC 顺序）
      assert {:error, "你现在经验尚浅，还是多在江湖上走走吧。\n"} =
               SectMaster.recruit_gate?(nil, student(-40_000, 499_999, %{}), bo)

      # 斗转星移不足 → 第一技能文案
      assert {:error, "斗转星移乃我慕容世家绝技，你不好好练习到我这来做甚？。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(-40_000, 500_000, %{"douzhuan-xingyi" => 129}),
                 bo
               )

      # 轻功不足 → 第三技能文案（recruit_skill_order 生效）
      assert {:error, "我慕容世家武功需配合灵巧的身法。你是否还应该在轻功修为上多下点功夫？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(
                   -40_000,
                   500_000,
                   %{"douzhuan-xingyi" => 130, "murong-xinfa" => 120, "dodge" => 199}
                 ),
                 bo
               )

      assert :ok =
               SectMaster.recruit_gate?(
                 nil,
                 student(
                   -40_000,
                   500_000,
                   %{"douzhuan-xingyi" => 130, "murong-xinfa" => 120, "dodge" => 200}
                 ),
                 bo
               )
    end
  end
end
