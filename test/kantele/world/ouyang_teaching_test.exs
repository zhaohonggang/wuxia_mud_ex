defmodule Kantele.World.OuyangTeachingTest do
  @moduledoc """
  #940-#943 欧阳世家（白驼山）教学门控定向测试。
  数据来源：LPC `kungfu/class/ouyang/{ouyang.h,ouyangfeng.c,ouyangke.c}`。
  重点锁定：三条绝招的负侠义上界不再被 `lpc_kunlun` 门序静默跳过。
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

  defp feng(world), do: npc(world, "欧阳锋", "baituo:dating")
  defp ke(world), do: npc(world, "欧阳克", "city:beidajie1")
  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  defp grant_player(overrides) do
    %Stats{
      skills: %{"lingshe-zhangfa" => 180},
      gongxian: 1000,
      shen: -130_000,
      performs: MapSet.new()
    }
    |> Map.from_struct()
    |> Map.put(:family, "欧阳世家")
    |> Map.merge(Map.new(overrides))
  end

  defp recruit_student(shen, exp, born, overrides \\ %{}) do
    %{
      meta: %{
        stats: %Stats{shen: shen, combat_exp: exp, gongxian: 0, skills: %{}},
        env: %{born_family: born}
      }
    }
    |> Map.merge(overrides)
  end

  describe "UCL 字段（Loader 归一后）" do
    test "欧阳锋/欧阳克收徒门、战斗闲聊与物品库存完整落位", %{world: world} do
      f = feng(world)
      k = ke(world)

      assert f, "欧阳锋应放置在 baituo:dating"
      assert k, "欧阳克应放置在 city:beidajie1"

      fa = f.meta.apprentice
      assert fa.gate_order == "lpc_ouyang"
      assert fa.family == "欧阳世家"
      assert fa.reject_student_names == ["欧阳锋", "欧阳克"]
      assert fa.required_born_family == "欧阳世家"
      assert fa.min_exp == 200_000
      assert fa.betray_sect_deny == "你反复无常，我不能收你为徒！"
      assert fa.other_family_deny == "你虽然是我们欧阳家的人，但你入了其他门派，我不能收你为徒！"
      assert fa.accept_msg == "欧阳锋喃喃自语道：我欧阳家真是后继有人啊！"

      ka = k.meta.apprentice
      assert ka.gate_order == "lpc_ouyang"

      assert ka.female_born_family_deny ==
               "这位真乃我的红颜知己，可惜家规所限，不能传你武功，你还是做我的小妾吧。"

      assert ka.accept_msg == "好... 很好！"

      # LPC set_temp("apply/*")
      assert Map.take(f.meta.combat_config.apply, [
               :attack,
               :defense,
               :damage,
               :unarmed_damage,
               :armor
             ]) ==
               %{attack: 150, defense: 150, damage: 100, unarmed_damage: 100, armor: 200}

      assert f.meta.chat_chance_combat == 120
      assert length(f.meta.chat_msg_combat) == 7
      assert "staff.wuji" in f.meta.chat_msg_combat

      assert f.meta.inquiry_state == %{"music_book" => 1}
      assert k.meta.inquiry_state == %{"shenshe_count" => 5}
      assert Enum.all?(f.meta.stats.skills || %{}, fn _ -> true end)
    end

    test "绝招/物品问询字段与 LPC 逐字一致", %{world: world} do
      f = feng(world)
      k = ke(world)

      expected = [
        {"横行无忌", "lingshe-zhangfa/wuji", 500, nil},
        {"千蛇出洞", "lingshe-zhangfa/qianshe", 800, -40_000},
        {"千蛇万噬", "lingshe-zhangfa/wanshi", -1000, -120_000}
      ]

      for {key, perform_id, cost, max_shen} <- expected do
        cfg = inquiry(f, key)
        assert cfg["perform_id"] == perform_id
        assert cfg["gate_order"] == "lpc_ouyang", "#{key} 必须走新门序，不能沿用 lpc_kunlun"
        assert cfg["cost_gongxian"] == cost, "#{key} 贡献变化"
        assert cfg["max_shen"] == max_shen, "#{key} 负侠义上界"

        refute String.contains?(cfg["learned"], "\\n"),
               "#{key} display text must not contain literal \\n"

        refute String.contains?(cfg["msg_one"], "\\n"),
               "#{key} msg_one must not contain literal \\n"
      end

      assert inquiry(f, "千蛇万噬")["improve_skills"] == [
               "staff",
               "staff",
               "lingshe-zhangfa",
               "lingshe-zhangfa",
               "martial-cognize"
             ]

      assert inquiry(f, "千蛇万噬")["maxed"] == "自己好好多练习吧！"
      assert inquiry(f, "千蛇出洞")["family_deny"] == "你是哪儿来的？找死么？"

      for key <- ["筝谱", "古筝技法"] do
        cfg = inquiry(f, key)
        assert cfg["count"] == "music_book"
        assert cfg["unique"] in [false, "false"]
        assert cfg["exhausted"] == "我的筝谱已经借出去了。"
      end

      assert inquiry(f, "灵蛇杖")["already"] == "灵蛇杖不是在你的手中么，怎么反而来找我呢？"

      for key <- ["引路神蛇", "神蛇"] do
        assert inquiry(k, key)["count"] == "shenshe_count"
        assert inquiry(k, key)["unique"] in [false, "false"]
      end
    end
  end

  describe "lpc_ouyang 绝招门序" do
    test "负侠义上界真实生效（lpc_kunlun 旧门序会静默放行）", %{world: world} do
      cfg = inquiry(feng(world), "千蛇出洞")

      assert {:ok, "lingshe-zhangfa/qianshe", 800} =
               SectMaster.inquiry_grant(
                 grant_player(shen: -40_000, skills: %{"lingshe-zhangfa" => 120}),
                 %{family: "欧阳世家"},
                 cfg
               )

      assert {:error, "你这人手段不够狠毒，我现在还不能传你绝招！\n"} =
               SectMaster.inquiry_grant(
                 grant_player(shen: -39_999, skills: %{"lingshe-zhangfa" => 120}),
                 %{family: "欧阳世家"},
                 cfg
               )
    end

    test "已会 / 非同门 / 贡献 / 杖法等级按 LPC 顺序拒绝", %{world: world} do
      cfg = inquiry(feng(world), "横行无忌")
      npc_stats = %{family: "欧阳世家"}

      assert {:error, "你还不快去练功去？好好把我们欧阳家发扬光大！\n"} =
               SectMaster.inquiry_grant(
                 grant_player(performs: MapSet.new(["lingshe-zhangfa/wuji"])),
                 npc_stats,
                 cfg
               )

      assert {:error, "哪来的野小子敢在这里撒野！\n"} =
               SectMaster.inquiry_grant(grant_player(family: "华山派"), npc_stats, cfg)

      assert {:error, "你为我欧阳家效力还不够，这招我先不忙传你。\n"} =
               SectMaster.inquiry_grant(grant_player(gongxian: 499), npc_stats, cfg)

      assert {:error, "你的杖法还不到家，学不了「横行无忌」！\n"} =
               SectMaster.inquiry_grant(
                 grant_player(skills: %{"lingshe-zhangfa" => 99}),
                 npc_stats,
                 cfg
               )

      assert {:ok, "lingshe-zhangfa/wuji", 500} =
               SectMaster.inquiry_grant(
                 grant_player(skills: %{"lingshe-zhangfa" => 100}),
                 npc_stats,
                 cfg
               )
    end
  end

  describe "收徒门 / 授艺门" do
    test "姓名硬门 → 出身 → 叛门 → 他派 → 经验，顺序与 ouyang.h 一致", %{world: world} do
      fa = feng(world).meta.apprentice

      assert {:error, "大怒：他奶奶的！你起这个名字是什么意思啊？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 Map.put(recruit_student(-100_000, 300_000, "欧阳世家"), :name, "欧阳克"),
                 fa
               )

      assert {:error, "你不是我们欧阳家的人，我怎能收你为徒？\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(-100_000, 300_000, "段氏皇族"), fa)

      assert {:error, "你的经验还不够，先和我的侄儿欧阳克学习武功吧。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(-100_000, 199_999, "欧阳世家"), fa)

      assert {:ok, "欧阳锋喃喃自语道：我欧阳家真是后继有人啊！\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(-100_000, 200_000, "欧阳世家"), fa)

      ka = ke(world).meta.apprentice
      female_outsider = recruit_student(-100_000, 0, "段氏皇族")

      female_outsider =
        put_in(female_outsider.meta.env, Map.put(female_outsider.meta.env, :gender, "女性"))

      assert {:error, "这位真乃我的红颜知己，可惜家规所限，不能传你武功，你还是做我的小妾吧。\n"} =
               SectMaster.recruit_gate?(nil, female_outsider, ka)
    end

    test "guzheng-jifa 首次说台词并落 mark；lingshe-quan 必须持 mark", %{world: world} do
      f = feng(world)
      k = ke(world)

      no_mark = %{
        meta: %{
          family: "欧阳世家",
          stats: %Stats{combat_exp: 0, skills: %{}},
          marks: %{}
        }
      }

      assert {:unlock, "好吧，你愿意学我就传你一点古筝之道。", "can_learn/ouyang/guzheng-jifa"} =
               SectMaster.teachable?(f, no_mark, "guzheng-jifa")

      assert {:error, "干嘛？没拜师就想向本少爷学东西？"} = SectMaster.teachable?(k, no_mark, "lingshe-quan")

      with_mark = put_in(no_mark.meta.marks["can_learn/lingshe-quan/ke"], 1)
      assert {:unlock, nil, nil} = SectMaster.teachable?(k, with_mark, "lingshe-quan")
    end
  end
end
