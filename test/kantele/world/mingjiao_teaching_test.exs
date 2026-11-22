defmodule Kantele.World.MingjiaoTeachingTest do
  @moduledoc """
  #933 明教教学门控回填定向测试：UCL 加载后的门控字段 + 引擎门序联验。
  数据来源：LPC `kungfu/class/mingjiao/*.c` 与 `adm/daemons/masterd.c`。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name, room_id) do
    Enum.find(world.characters, fn c -> c.name == name and c.room_id == room_id end)
  end

  defp inquiry(npc, key), do: npc.meta.inquiries[key]

  defp student(skills, exp, shen) do
    stats = %Stats{
      skills: skills,
      combat_exp: exp,
      shen: shen,
      gongxian: 2000,
      performs: MapSet.new()
    }

    %{meta: %{stats: stats}}
  end

  describe "UCL 数据回填（Loader 归一后）" do
    test "7 位 F_MASTER 的 teach/apprentice 门控字段与 LPC attempt_apprentice 一致", %{world: world} do
      cases = [
        {"张无忌", "mingjiao:dadian", "明教", 90_000, 800_000, "shenghuo-xinfa", 180},
        {"杨逍", "mingjiao:dadian", "明教", 80_000, 700_000, "shenghuo-xinfa", 160},
        {"韦一笑", "mingjiao:dadian", "明教", 10_000, 0, "shenghuo-xinfa", 100},
        {"谢逊", "mingjiao:dadian", "明教", 40_000, 380_000, "shenghuo-xinfa", 140},
        {"殷天正", "mingjiao:dadian", "明教", 60_000, 450_000, "shenghuo-xinfa", 180},
        {"黛绮丝", "mingjiao:dadian", "明教", 60_000, 450_000, "shenghuo-xinfa", 180},
        {"冷谦", "mingjiao:rjqyuan", "明教", 0, 0, nil, nil}
      ]

      for {name, room, family, shen, exp, _skill, _level} <- cases do
        ob = npc(world, name, room)
        assert ob, "#{name} 应随世界加载（#{room}）"
        assert ob.meta.teach.family == family, "#{name} teach.family"
        assert ob.meta.apprentice.family == family, "#{name} apprentice.family"
        assert ob.meta.apprentice.gate_order == "lpc_mingjiao", "#{name} gate_order"
        assert ob.meta.apprentice.permit_recruit == true
        assert ob.meta.apprentice.min_shen == shen, "#{name} min_shen"
        assert ob.meta.apprentice.min_exp == exp, "#{name} min_exp"
        assert ob.meta.apprentice.betray_sect_deny == "我们明教教规你还记得吗，你还有脸回来！"
        assert ob.meta.apprentice.betray_times_deny == "哼，阁下不忠不信，我们明教可不会收留。"
        assert ob.meta.apprentice.other_family_deny == "阁下既有了师承，还来我们明教做什么？"
      end

      zw = npc(world, "张无忌", "mingjiao:dadian")

      assert zw.meta.apprentice.min_skills == %{
               "shenghuo-xinfa" => 180,
               "force" => 180
             }

      assert zw.meta.apprentice.recruit_skill_order == ["shenghuo-xinfa", "force"]
      assert zw.meta.apprentice.min_exp_deny == "你江湖经验还不够，下去多磨练一下吧！"
      assert zw.meta.teach.no_teach_deny["qishang-quan"] == "想学七伤拳你还是找我义父谢逊吧！"
      assert zw.meta.teach.teach_skills["jiuyang-shengong"].max == 360

      lq = npc(world, "冷谦", "mingjiao:rjqyuan")
      assert lq.meta.apprentice.min_skills == %{}
      assert lq.meta.apprentice.min_shen_deny == "阁下身染邪气，还是及早回头得好。"
      assert lq.meta.apprentice.accept_msg == "好，好，今日我就收你为弟子，从此你便入我明教，信奉明尊。"

      # 非师父 NPC：范遥/小昭只带 coagents，不带 teach/apprentice。
      assert npc(world, "范遥", "mingjiao:dadian").meta.teach == nil
      assert npc(world, "小昭", "mingjiao:neishi").meta.teach == nil
    end

    test "23 条绝招 + 幻灵剑 give_item 的门控字段归一", %{world: world} do
      expected = [
        {"张无忌", "mingjiao:dadian", 9},
        {"杨逍", "mingjiao:dadian", 4},
        {"黛绮丝", "mingjiao:dadian", 2},
        {"韦一笑", "mingjiao:dadian", 2},
        {"谢逊", "mingjiao:dadian", 3},
        {"殷天正", "mingjiao:dadian", 2},
        {"冷谦", "mingjiao:rjqyuan", 1}
      ]

      total =
        Enum.reduce(expected, 0, fn {name, room, count}, acc ->
          ob = npc(world, name, room)

          grants =
            Enum.filter(Map.keys(ob.meta.inquiries), fn k ->
              is_map(ob.meta.inquiries[k]) and
                ob.meta.inquiries[k]["kind"] == "sect_master_grant"
            end)

          assert length(grants) == count, "#{name} 绝招数应为 #{count}，实为 #{length(grants)}"
          acc + count
        end)

      assert total == 23, "明教 23 条师门绝招（幻灵剑 give_item 单列）"

      zw = npc(world, "张无忌", "mingjiao:dadian")
      xi = inquiry(zw, "吸焰令")
      assert xi["perform_id"] == "shenghuo-ling/xi"
      assert xi["skill"] == "shenghuo-ling"
      assert xi["min_levels"] == %{"shenghuo-ling" => 140, "max-neili" => 2000}
      assert xi["level_order"] == ["shenghuo-ling", "max-neili"]
      assert xi["min_shen"] == 100_000
      assert xi["min_gongxian"] == 800
      assert xi["cost_gongxian"] == 800
      assert xi["level_deny"]["max-neili"] == "你现在的内力修为不足，修炼高点再来吧。"

      free = inquiry(zw, "金阳破岭")
      assert free["no_family_check"] == "true"

      assert free["min_levels"] == %{
               "jiuyang-shengong" => 220,
               "sword" => 240,
               "force" => 240,
               "max-neili" => 5500
             }

      assert free["level_order"] == ["jiuyang-shengong", "sword", "force", "max-neili"]
      refute Map.has_key?(free, "min_shen")

      yx = npc(world, "杨逍", "mingjiao:dadian")
      sword = inquiry(yx, "幻灵剑")
      assert sword["kind"] == "give_item"
      assert sword["item"] == "clone_lib:huanlingjian"
      assert sword["master_id"] == "true"
      assert sword["min_shen"] == 80_000
      assert sword["min_skill_levels"] == %{"xiaoyao_jian" => 120}

      # coagents / 战斗闲聊
      assert hd(yx.meta.coagents)["id"] == "zhang wuji"
      assert hd(yx.meta.coagents)["startroom"] == "mingjiao:dadian"
      assert zw.meta.chat_chance_combat == 120
      assert "perform sword.hua" in zw.meta.chat_msg_combat
      assert "recover" in zw.meta.chat_msg_combat
      assert yx.meta.chat_chance_combat == 20
    end

    test "小昭 10 条问询已从占位符替换为 LPC 逐字文案", %{world: world} do
      xz = npc(world, "小昭", "mingjiao:neishi")
      assert xz, "小昭应在 mingjiao:neishi"
      assert inquiry(xz, "张无忌") == "小昭幽幽地说：天涯思君不可忘，东西永隔如参商。"
      assert inquiry(xz, "wuji") == inquiry(xz, "张无忌")
      assert inquiry(xz, "倚天剑") == "我不知道在哪里...别问我。"
      assert inquiry(xz, "黄金") == "不行啊，这不能随便给人。"
      assert String.contains?(inquiry(xz, "歌"), "世情推物理  人生贵适意")
      assert String.contains?(inquiry(xz, "乾坤大挪移"), "后来张公子才在密道里面找了回来。")
      refute String.contains?(inspect(xz.meta.inquiries), "unimplemented")
    end
  end

  describe "引擎门序联验（真实 UCL 配置）" do
    test "lpc_mingjiao：shen → 技能（先于经验）→ exp", %{world: world} do
      gate = npc(world, "张无忌", "mingjiao:dadian").meta.apprentice

      # 侠义不足优先于一切（shen 90000）
      assert {:error, "你行侠仗义的事做得还不够，还是请回吧。\n"} =
               SectMaster.recruit_gate?(nil, student(%{}, 0, 89_999), gate)

      # 圣火心法不足 + 经验足够：必须报技能文案（而非经验文案）
      assert {:error, "你圣火心法不够娴熟，还是下去多练习一下吧！\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(%{"shenghuo-xinfa" => 179, "force" => 200}, 900_000, 100_000),
                 gate
               )

      # 圣火心法够、基本内功不足：第二技能文案
      assert {:error, "你基本内功火候不够，怎么学我明教的圣火神功！\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(%{"shenghuo-xinfa" => 180, "force" => 179}, 900_000, 100_000),
                 gate
               )

      # 两技能都够、经验不足：经验最后判
      assert {:error, "你江湖经验还不够，下去多磨练一下吧！\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(%{"shenghuo-xinfa" => 180, "force" => 180}, 799_999, 100_000),
                 gate
               )

      assert :ok =
               SectMaster.recruit_gate?(
                 nil,
                 student(%{"shenghuo-xinfa" => 180, "force" => 180}, 800_000, 100_000),
                 gate
               )

      assert gate.accept_msg =~ "今日我就收你为弟子"
    end

    test "lpc_masterd 授艺：neili 读最大内力、free 跳过同门、拒绝文案逐字", %{world: world} do
      zw = npc(world, "张无忌", "mingjiao:dadian")
      npc_stats = %{family: "明教"}

      good =
        %Stats{
          shen: 100_000,
          gongxian: 800,
          skills: %{"shenghuo-ling" => 140},
          performs: MapSet.new()
        }
        |> Map.put(:family, "明教")
        |> Map.put(:max_neili, 2000)

      assert {:ok, "shenghuo-ling/xi", 800} =
               SectMaster.inquiry_grant(good, npc_stats, inquiry(zw, "吸焰令"))

      # 最大内力 1999 < 2000 → 内力文案（不是技能文案）
      weak_neili = %{good | max_neili: 1999}

      assert {:error, "你现在的内力修为不足，修炼高点再来吧。\n"} =
               SectMaster.inquiry_grant(weak_neili, npc_stats, inquiry(zw, "吸焰令"))

      # free:1 绝招：非本门玩家也能学（same_family 被跳过）
      outsider = %{
        good
        | family: "少林派",
          skills: %{"jiuyang-shengong" => 220, "sword" => 240, "force" => 240},
          max_neili: 5500
      }

      assert {:ok, "jiuyang-shengong/po", 0} =
               SectMaster.inquiry_grant(outsider, npc_stats, inquiry(zw, "金阳破岭"))

      # 非 free 绝招对非本门玩家仍拒绝
      assert {:error, "与我明教素无渊源，不知此话从何说起。"} =
               SectMaster.inquiry_grant(outsider, npc_stats, inquiry(zw, "吸焰令"))

      # 绝招已学会 → maxed 文案
      known = %{good | performs: MapSet.new(["shenghuo-ling/xi"])}

      assert {:error, "自己下去练，还来罗嗦什么。"} =
               SectMaster.inquiry_grant(known, npc_stats, inquiry(zw, "吸焰令"))
    end
  end
end
