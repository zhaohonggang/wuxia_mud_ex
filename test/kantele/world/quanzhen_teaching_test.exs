defmodule Kantele.World.QuanzhenTeachingTest do
  @moduledoc """
  #951-#955 全真教（quanzhen）教学门控定向测试。
  数据来源：LPC `kungfu/class/quanzhen/*`；重点锁定 lpc_quanzhen 的
  收徒门序、18 条绝招门序、周伯通左右互搏标记门与逐字拒绝文案。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @tag :quanzhen
  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name) do
    Enum.find(world.characters, fn c ->
      c.name == name and (c.meta.teach != nil or c.meta.apprentice != nil)
    end) || Enum.find(world.characters, &(&1.name == name))
  end

  defp npc!(world, name) do
    npc(world, name) || raise("missing quanzhen NPC #{name}")
  end

  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  # inquiry_grant/3 的玩家侧是「扁平 stats map」（与 ouyang_teaching_test.exs 同源）：
  # skill_level_of/stat 直接按顶层键取值，不读 meta 壳。
  defp grant_player(overrides) do
    opts = Map.new(overrides)

    # skills 传入时整体替换（不能 Map.merge 外层：默认值会残留 qixing-shou/xiantian-gong
    # 到用例的 skills map 里，让「未学该技能」门永不触发）。
    %Stats{
      skills: %{
        "qixing-shou" => 200,
        "force" => 250,
        "xiantian-gong" => 240
      },
      gongxian: 3000,
      # 逐 NPC 侠义门槛不同（郝大通 3 万 / 马钰 5 万 / 丘处机 3 万），默认取最大值，
      # 用例只压低于门槛的那一支。
      shen: 150_000,
      performs: MapSet.new()
    }
    |> Map.from_struct()
    |> Map.put(:max_neili, 6_000)
    |> Map.put(:family, "全真教")
    |> Map.merge(Map.drop(opts, [:skills]))
    |> then(fn m -> if skills = opts[:skills], do: %{m | skills: skills}, else: m end)
  end

  defp student(overrides) do
    opts = Map.new(overrides)

    stats =
      %Stats{
        int: 40,
        # 王重阳要 8 万侠义，默认给足；压门槛的用例单独传 min。
        shen: 200_000,
        combat_exp: 600_000,
        gongxian: 10_000,
        skills: %{"xuanmen-neigong" => 160, "quanzhen-xinfa" => 160, "sword" => 160}
      }
      |> Map.from_struct()
      |> Map.put(:max_neili, 6_000)
      |> Map.merge(Map.get(opts, :stats, %{}))

    %{
      meta: %{
        stats: stats,
        env: Map.get(opts, :env, %{}),
        family: Map.get(opts, :family)
      }
    }
  end

  describe "UCL 字段（Loader 归一后）" do
    test "22 个 class/quanzhen NPC 全部落 teach / apprentice / 战斗闲聊", %{world: world} do
      names = [
        "陈志益",
        "程瑶迦",
        "崔志方",
        "房志起",
        "郝大通",
        "姬清虚",
        "李志常",
        "刘处玄",
        "马钰",
        "皮清玄",
        "祁志诚",
        "丘处机",
        "申志凡",
        "孙不二",
        "谭处端",
        "王重阳",
        "王处一",
        "王志坦",
        "尹志平",
        "张志光",
        "赵志敬",
        "周伯通"
      ]

      for name <- names do
        c = npc!(world, name)
        teach = c.meta.teach || raise("#{name} 缺 teach")
        assert teach.family == "全真教", "#{name} teach.family"
        assert map_size(teach.teach_skills) > 0, "#{name} teach_skills 不能为空"

        ap = c.meta.apprentice || raise("#{name} 缺 apprentice")

        if ap.deny_all == true do
          assert is_binary(ap.deny_msg)
        else
          assert ap.gate_order == "lpc_quanzhen", "#{name} gate_order"
          assert is_binary(ap.recruit_profile)
        end

        assert c.meta.chat_chance_combat == 120, "#{name} chat_chance_combat"
        assert length(c.meta.chat_msg_combat) > 0, "#{name} chat_msg_combat"
      end
    end

    test "刘处玄 2 键 / 王重阳 前置绝招 / 丘处机 coagents / 六人 apply", %{world: world} do
      liu = npc!(world, "刘处玄")

      for key <- ["连环掌", "重阳连环掌"] do
        cfg = inquiry(liu, key)
        assert cfg["kind"] == "sect_master_grant"
        assert cfg["gate_order"] == "lpc_quanzhen"
        assert cfg["perform_id"] == "chongyang-shenzhang/lian"
        assert cfg["level_order"] == ["chongyang-shenzhang", "force"]
        assert cfg["improve_skills"] == ["strike", "chongyang-shenzhang", "martial-cognize"]
      end

      wang = npc!(world, "王重阳")

      assert inquiry(wang, "神威浩荡")["requires_perform"] == "xiantian-gong/fen"
      assert inquiry(wang, "神威浩荡")["level_order"] == ["xiantian-gong", "max-neili"]
      assert inquiry(wang, "全真教") == "我全真教是天下道家玄门正宗。"

      qiu = npc!(world, "丘处机")

      assert Enum.map(qiu.meta.coagents, fn c ->
               {Map.get(c, "id") || Map.get(c, :id),
                Map.get(c, "startroom") || Map.get(c, :startroom)}
             end) == [
               {"ma yu", "quanzhen:shiweishi"},
               {"wang chuyi", "quanzhen:wanwutang"}
             ]

      for {name, damage, armor} <- [
            {"刘处玄", 100, 200},
            {"马钰", 100, 200},
            {"丘处机", 100, 200},
            {"谭处端", 100, 200},
            {"王重阳", 100, 200},
            {"周伯通", 200, 600}
          ] do
        apply = npc!(world, name).meta.combat_config.apply
        assert apply.damage == damage, "#{name} apply.damage"
        assert apply.armor == armor, "#{name} apply.armor"
      end
    end

    test "18 条绝招全部走 lpc_quanzhen 且显示文案无字面 \\n", %{world: world} do
      cases = [
        {"郝大通", ["破穹云蛟"]},
        {"刘处玄", ["连环掌", "重阳连环掌"]},
        {"马钰", ["玄门金锁"]},
        {"丘处机", ["玉石俱焚"]},
        {"孙不二", ["朝拜天罡"]},
        {"谭处端", ["三花聚顶"]},
        {"王重阳", ["五气朝元", "一气化三清", "化三清", "天地混元", "五阴焚灭", "神威浩荡"]},
        {"王处一", ["缠字诀", "定阳针"]},
        {"尹志平", ["剑指南山", "群星璀璨", "三连环"]},
        {"周伯通", ["空明若玄", "空空如也"]}
      ]

      for {name, keys} <- cases, key <- keys do
        cfg = inquiry(npc!(world, name), key) || raise("#{name} 缺 #{key}")
        assert cfg["gate_order"] == "lpc_quanzhen", "#{name}/#{key} 仍用旧门序"
        refute String.contains?(cfg["msg_one"], "\\n"), "#{name}/#{key} msg_one 字面 \\n"
        refute String.contains?(cfg["learned"], "\\n"), "#{name}/#{key} learned 字面 \\n"
        refute String.contains?(cfg["maxed"], "\\n"), "#{name}/#{key} maxed 字面 \\n"
      end
    end
  end

  describe "lpc_quanzhen 绝招门序" do
    test "郝大通：已会 → 同门 → 贡献 → 侠义 → 有序等级链", %{world: world} do
      cfg = inquiry(npc!(world, "郝大通"), "破穹云蛟")
      npc_stats = %{family: "全真教"}
      ok = grant_player(%{})

      assert {:ok, "qixing-shou/po", 800} = SectMaster.inquiry_grant(ok, npc_stats, cfg)

      assert {:error, "这招我不是已经教会你了吗？\n"} =
               SectMaster.inquiry_grant(
                 grant_player(performs: MapSet.new(["qixing-shou/po"])),
                 npc_stats,
                 cfg
               )

      assert {:error, "阁下与贫道素不相识，不知此话从何说起？\n"} =
               SectMaster.inquiry_grant(grant_player(family: "华山派"), npc_stats, cfg)

      assert {:error, "你在我全真教内甚无作为，这招我暂时还不能传你。\n"} =
               SectMaster.inquiry_grant(grant_player(gongxian: 799), npc_stats, cfg)

      assert {:error, "你的侠义正事还做得不够，这招我暂时还不能传你。\n"} =
               SectMaster.inquiry_grant(grant_player(shen: 29_999), npc_stats, cfg)

      assert {:error, "你的七星分天手不够娴熟，练高点再来吧。\n"} =
               SectMaster.inquiry_grant(
                 grant_player(skills: %{"qixing-shou" => 149, "force" => 250}),
                 npc_stats,
                 cfg
               )

      assert {:error, "你的内功修为不够，修炼高后再来找我吧。\n"} =
               SectMaster.inquiry_grant(
                 grant_player(skills: %{"qixing-shou" => 200, "force" => 199}),
                 npc_stats,
                 cfg
               )
    end

    test "王重阳神威浩荡：前置绝招门在内力门之后", %{world: world} do
      cfg = inquiry(npc!(world, "王重阳"), "神威浩荡")
      npc_stats = %{family: "全真教"}

      assert {:error, "此招乃是由「五阴焚灭」升华而来，你还是逐步学习吧？\n"} =
               SectMaster.inquiry_grant(grant_player(%{}), npc_stats, cfg)

      assert {:error, "你的内力修为仍不足，还是练高点再来吧。\n"} =
               SectMaster.inquiry_grant(
                 grant_player(max_neili: 4_999, performs: MapSet.new(["xiantian-gong/fen"])),
                 npc_stats,
                 cfg
               )

      assert {:ok, "xiantian-gong/dang", 2500} =
               SectMaster.inquiry_grant(
                 grant_player(performs: MapSet.new(["xiantian-gong/fen"])),
                 npc_stats,
                 cfg
               )
    end
  end

  describe "lpc_quanzhen 收徒门" do
    test "丘处机：内功 OR → 剑法 → 侠义，文案逐字", %{world: world} do
      cfg = npc!(world, "丘处机").meta.apprentice

      assert {:ok, msg} = SectMaster.recruit_gate?(nil, student(%{}), cfg)
      assert String.contains?(msg, "我收下你便是，但你可别坏了我们全真七子的名头。")
      assert String.contains?(msg, "假如某日我知道你在外面作恶，照样会杀了你。")

      assert {:error, "你连本门最基本的内功都未练足，叫我如何收你？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(stats: %{skills: %{"xuanmen-neigong" => 99, "sword" => 160}}),
                 cfg
               )

      assert {:error, "你的剑法差成这样，如何能够杀敌？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(stats: %{skills: %{"xuanmen-neigong" => 160, "sword" => 99}}),
                 cfg
               )

      assert {:error, "你目前表现太差！多做点行侠仗义的事再来找我！\n"} =
               SectMaster.recruit_gate?(nil, student(stats: %{shen: 24_999}), cfg)
    end

    test "王重阳：悟性 → 内功 → 经验 → 侠义；孙不二拒男徒；周伯通经验先行", %{world: world} do
      wang = npc!(world, "王重阳").meta.apprentice

      assert {:error, "你的悟性还不够，还是先找我那几个徒弟学习吧。\n"} =
               SectMaster.recruit_gate?(nil, student(stats: %{int: 34}), wang)

      assert {:error, "你的本门内功心法火候不足，只怕难以领略更高深的武功。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(stats: %{skills: %{"xuanmen-neigong" => 119}}),
                 wang
               )

      assert {:error, "你的实战经验太差，看来难以领略更高深的武功。\n"} =
               SectMaster.recruit_gate?(nil, student(stats: %{combat_exp: 449_999}), wang)

      assert {:error, "行侠仗义是我辈学武人的宗旨，你多做些侠义之事，我方能收你为徒。\n"} =
               SectMaster.recruit_gate?(nil, student(stats: %{shen: 79_999}), wang)

      sun = npc!(world, "孙不二").meta.apprentice

      assert {:error, "我不收男徒，你还是去拜我几位师兄为师吧。\n"} =
               SectMaster.recruit_gate?(nil, student(env: %{gender: "男性"}), sun)

      zhou = npc!(world, "周伯通").meta.apprentice

      assert {:error, "你经验这么差，还是去找我那几个师侄教你吧。\n"} =
               SectMaster.recruit_gate?(nil, student(stats: %{combat_exp: 399_999}), zhou)

      # zhou.c:140 侠义 5 万硬门，经验达标也要拦。
      assert {:error, "你这人品行不好，跟你一起肯定做不了什么好事。\n"} =
               SectMaster.recruit_gate?(nil, student(stats: %{shen: 49_999}), zhou)

      # zhou.c:274 拜师学艺经验 50 万（问 skill 的那条路）。
      assert {:ok, msg} = SectMaster.recruit_gate?(nil, student(%{}), zhou)
      assert String.contains?(msg, "反正最近也没啥事干，就收下你玩玩吧。")
    end
  end

  describe "周伯通 recognize_apprentice" do
    test "只认左右互搏标记，经验不能解锁，非本技能走专属文案", %{world: world} do
      zhou = npc!(world, "周伯通")

      no_mark = %{
        meta: %{
          family: "全真教",
          stats: %Stats{combat_exp: 9_000_000, skills: %{}},
          marks: %{}
        }
      }

      # 无标记一律拒（标志由 accept_fight → lost() 写入，经验 900 万也不能解锁）。
      assert {:error, "做了个鬼脸，说道：我又不是你师父，为啥要教你？"} =
               SectMaster.teachable?(zhou, no_mark, "zuoyou-hubo")

      with_mark = put_in(no_mark.meta.marks["can_learn/zuoyou-hubo/zhou"], 1)

      assert {:unlock, nil, nil} = SectMaster.teachable?(zhou, with_mark, "zuoyou-hubo")

      # 有标记但非左右互搏 → LPC zhou.c:160 的专属文案。
      assert {:error, "你的武功比我还好，你教我还差不多。"} = SectMaster.teachable?(zhou, with_mark, "force")
    end
  end
end
