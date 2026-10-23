defmodule Kantele.World.InquirySectMastersTest do
  @moduledoc """
  P5-4at：门派师父 `ask_skillN` 绝招问询的数据回填 + 门控联验。

  覆盖 5 个 NPC（LPC `kungfu/class/**` 的 ask_skill 闭包）：
    - heimuya/ren     任我行   5 门（日月神教）
    - kaifeng/wuchen  无尘道长 3 门（红花会）
    - xuedao/baoxiang 宝象     1 门（血刀门）
    - xuedao/shengdi  胜谛     1 门（血刀门）
    - guanwai/pingsi  平四     4 条纯文本问询

  断言分两层：① UCL 数据经 Loader 归一后的门控字段（含 min_levels 的
  `_`→`-` 键归一）；② 用**加载出来的真实配置**喂 `SectMaster.inquiry_grant/3`，
  验证同门派玩家过门 / 差贡献、杀气、内力时各走哪条拒绝文案。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster

  setup_all do
    %{world: Kantele.World.Loader.load()}
  end

  # ---- NPC 定位（角色 id 是加载时生成的哈希，按 名字 + 房间 找） ----

  defp npc(world, name, room_id) do
    Enum.find(world.characters, fn c -> c.name == name and c.room_id == room_id end)
  end

  defp inquiry(npc, key), do: npc.meta.inquiries[key]

  # 同门派弟子（门派名按 NPC 传入；技能/贡献/杀气/内力按用例覆盖）
  # family / max_neili 不是 %Stats{} 字段：inquiry_grant 的宿主由调用方
  # （npc_script_event.stats_with_family/1）补进 map，这里如实镜像。
  defp disciple(overrides \\ %{}) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, nil)
    |> Map.put(:max_neili, 0)
    |> Map.merge(overrides)
  end

  describe "UCL 数据回填（Loader 归一后）" do
    test "任我行 5 门绝招：门控字段与 LPC ask_skill1..5 一致", %{world: world} do
      npc = npc(world, "任我行", "heimuya:chengdedian")
      assert npc, "任我行应随世界加载（heimuya:chengdedian）"
      assert npc.meta.teach.family == "日月神教"

      expected = [
        {"天地归元", "yuanshi-jian/gui", 500, -120_000, nil, %{"force" => 200, "yuanshi-jian" => 140}, 500},
        {"天旋地转", "yuanshi-jian/xuan", 1400, -130_000, nil, %{"force" => 260, "yuanshi-jian" => 180}, 1400},
        {"大巧若拙", "guzhuo-zhang/zhuo", 600, -120_000, 1800, %{"force" => 220, "guzhuo-zhang" => 150}, 600},
        {"大智若愚", "guzhuo-zhang/yu", 1200, -150_000, 2800, %{"force" => 260, "guzhuo-zhang" => 180}, 1200},
        {"反璞归真", "guzhuo-zhang/zhen", 2200, -200_000, 3600, %{"force" => 300, "guzhuo-zhang" => 220}, 2200}
      ]

      for {key, perform_id, gongxian, max_shen, neili, levels, cost} <- expected do
        cfg = inquiry(npc, key)
        assert cfg, "任我行应能回答「#{key}」"

        assert cfg["perform_id"] == perform_id
        assert cfg["skill"] == String.split(perform_id, "/") |> List.first()
        assert cfg["min_gongxian"] == gongxian
        assert cfg["max_shen"] == max_shen
        assert cfg["cost_gongxian"] == cost
        # min_levels 键由 loader 归一为连字符（对齐 Stats.skills）
        assert cfg["min_levels"] == levels

        if neili do
          assert cfg["min_max_neili"] == neili
        else
          refute Map.has_key?(cfg, "min_max_neili")
        end

        # LPC 每招独立文案（*_deny 覆盖）
        assert cfg["family_deny"] == "你又不是我日月神教的，跑来捣什么乱？"
        assert cfg["max_shen_deny"] == "你这样心慈手软，就算学会这招又有什么用？"
        assert cfg["maxed"] == "这一招我不是已经教过你了吗？"
      end

      # 原始剑法两招 / 古拙掌法三招的技能未学文案不同
      assert inquiry(npc, "天地归元")["skill_deny"] == "你连原始剑法都没学，还谈什么绝招可言？"
      assert inquiry(npc, "大巧若拙")["skill_deny"] == "你连古拙掌法都没学，何谈绝招可言？"
    end

    test "无尘道长 3 门绝招：min_shen 下限 + 内力门槛", %{world: world} do
      npc = npc(world, "无尘道长", "kaifeng:hh_jianlou1")
      assert npc, "无尘道长应随世界加载（kaifeng:hh_jianlou1）"
      assert npc.meta.teach.family == "红花会"

      lian = inquiry(npc, "夺命连环")
      assert lian["perform_id"] == "lianhuan-mizongtui/lian"
      assert lian["skill"] == "lianhuan-mizongtui"
      assert lian["min_gongxian"] == 600
      assert lian["min_shen"] == 50_000
      assert lian["min_max_neili"] == 1800
      assert lian["min_levels"] == %{"force" => 150, "dodge" => 150, "lianhuan-mizongtui" => 120}
      assert lian["cost_gongxian"] == 600
      assert lian["family_deny"] == "大侠和本会素无瓜葛，何出此言？"
      assert lian["shen_deny"] == "你侠义正事做得不够，这招我不能传你。"

      zhui = inquiry(npc, "追魂夺命")
      assert zhui["perform_id"] == "zhuihun-jian/zhui"
      assert zhui["min_shen"] == 35_000
      assert zhui["min_max_neili"] == 800

      zhu = inquiry(npc, "诛天刹神")
      assert zhu["perform_id"] == "zhuihun-jian/zhu"
      assert zhu["min_shen"] == 80_000
      assert zhu["min_max_neili"] == 1800
      assert zhu["min_levels"] == %{"force" => 200, "zhuihun-jian" => 160}
    end

    test "宝象/胜谛 各 1 门：血刀门同门校验（teach.family）", %{world: world} do
      baoxiang = npc(world, "宝象", "xuedao:shandong2")
      assert baoxiang, "宝象应随世界加载（xuedao:shandong2）"
      assert baoxiang.meta.teach.family == "血刀门"

      huo = inquiry(baoxiang, "流星火雨")
      assert huo["perform_id"] == "honglian-dao/huo"
      assert huo["skill"] == "honglian-dao"
      assert huo["min_gongxian"] == 80
      assert huo["max_shen"] == -8000
      assert huo["min_max_neili"] == 800
      assert huo["min_levels"] == %{"force" => 120, "honglian-dao" => 80}
      assert huo["family_deny"] == "你又不是我血刀门的，再罗嗦我宰了你！"

      shengdi = npc(world, "胜谛", "xuedao:sroad9")
      assert shengdi, "胜谛应随世界加载（xuedao:sroad9）"
      assert shengdi.meta.teach.family == "血刀门"

      kai = inquiry(shengdi, "冰河开封")
      assert kai["perform_id"] == "xueshan-dao/kai"
      assert kai["min_gongxian"] == 50
      assert kai["max_shen"] == -3000
      assert kai["min_max_neili"] == 600
      assert kai["min_levels"] == %{"force" => 100, "xueshan-dao" => 80}
    end

    test "平四 4 条纯文本问询（出关/办事/出去 走 ask_me 传送，未回填）", %{world: world} do
      pingsi = npc(world, "平四", "guanwai:xiaoyuan")
      assert pingsi, "平四应随世界加载（guanwai:xiaoyuan）"

      assert inquiry(pingsi, "阎基") == "阎基…哼…这个狗贼。"
      assert inquiry(pingsi, "胡一刀") == "那……那是老主人，唉。"
      assert inquiry(pingsi, "苗人凤") == "苗大侠可不是坏人。"
      assert inquiry(pingsi, "赵半山") == "他对我家主人的交情那是没得说的。"

      for key <- ~w(出关 办事 出去) do
        refute Map.has_key?(pingsi.meta.inquiries, key),
               "「#{key}」是传送服务（ask_me），暂无对应 kind，不应以问答形式回填"
      end
    end
  end

  describe "门控联验（真实配置 + inquiry_grant/3）" do
    test "日月神教弟子全达标 → 学会「天地归元」并扣 500 贡献", %{world: world} do
      cfg = inquiry(npc(world, "任我行", "heimuya:chengdedian"), "天地归元")

      player =
        disciple(%{
          skills: %{"yuanshi-jian" => 140, "force" => 200},
          gongxian: 500,
          shen: -120_000,
          family: "日月神教"
        })

      assert {:ok, "yuanshi-jian/gui", 500} =
               SectMaster.inquiry_grant(player, %{family: "日月神教"}, cfg)
    end

    test "杀气不够阴（shen > -120000）→ max_shen_deny", %{world: world} do
      cfg = inquiry(npc(world, "任我行", "heimuya:chengdedian"), "天地归元")

      player =
        disciple(%{
          skills: %{"yuanshi-jian" => 140, "force" => 200},
          gongxian: 500,
          shen: -119_999,
          family: "日月神教"
        })

      assert {:error, "你这样心慈手软，就算学会这招又有什么用？"} =
               SectMaster.inquiry_grant(player, %{family: "日月神教"}, cfg)
    end

    test "内力不足（大巧若拙 1800）→ max_neili_deny", %{world: world} do
      cfg = inquiry(npc(world, "任我行", "heimuya:chengdedian"), "大巧若拙")

      player =
        disciple(%{
          skills: %{"guzhuo-zhang" => 150, "force" => 220},
          gongxian: 600,
          shen: -120_000,
          family: "日月神教",
          max_neili: 1799
        })

      assert {:error, "你的内力太差，怎么修炼上乘武功？"} =
               SectMaster.inquiry_grant(player, %{family: "日月神教"}, cfg)

      # 同一份配置，内力补齐即过门（min_max_neili 门控真实生效）
      assert {:ok, "guzhuo-zhang/zhuo", 600} =
               SectMaster.inquiry_grant(
                 %{player | max_neili: 1800},
                 %{family: "日月神教"},
                 cfg
               )
    end

    test "非红花会弟子 → family_deny（含敬称）", %{world: world} do
      cfg = inquiry(npc(world, "无尘道长", "kaifeng:hh_jianlou1"), "夺命连环")

      player =
        disciple(%{
          skills: %{"lianhuan-mizongtui" => 120, "force" => 150, "dodge" => 150},
          gongxian: 600,
          shen: 50_000,
          max_neili: 1800,
          family: "武当派"
        })

      assert {:error, "大侠和本会素无瓜葛，何出此言？"} =
               SectMaster.inquiry_grant(player, %{family: "红花会"}, cfg)
    end

    test "侠义不足（shen < 50000）→ shen_deny", %{world: world} do
      cfg = inquiry(npc(world, "无尘道长", "kaifeng:hh_jianlou1"), "夺命连环")

      player =
        disciple(%{
          skills: %{"lianhuan-mizongtui" => 120, "force" => 150, "dodge" => 150},
          gongxian: 600,
          shen: 49_999,
          max_neili: 1800,
          family: "红花会"
        })

      assert {:error, "你侠义正事做得不够，这招我不能传你。"} =
               SectMaster.inquiry_grant(player, %{family: "红花会"}, cfg)
    end

    test "血刀门外派 + 杀气过高 → 宝象 family_deny 先拦", %{world: world} do
      cfg = inquiry(npc(world, "宝象", "xuedao:shandong2"), "流星火雨")

      player =
        disciple(%{
          skills: %{"honglian-dao" => 80, "force" => 120},
          gongxian: 80,
          shen: 1000,
          max_neili: 800,
          family: "少林派"
        })

      assert {:error, "你又不是我血刀门的，再罗嗦我宰了你！"} =
               SectMaster.inquiry_grant(player, %{family: "血刀门"}, cfg)

      # 同门但心慈手软 → max_shen_deny
      assert {:error, "你这样心慈手软，就算学会这招又有什么用？"} =
               SectMaster.inquiry_grant(%{player | family: "血刀门"}, %{family: "血刀门"}, cfg)
    end
  end
end
