defmodule Kantele.World.EmeiFenglingMasterIdTest do
  @moduledoc """
  #852 风陵师太 `fengling.c ask_skill1/2` 的直传弟子门：

      me->query("family/family_name") != query("family/family_name") -> 非同门
      me->query("family/master_id")    != query("id")                -> 非本师弟子

  ex 侧必须把 `meta.family.master_id` 带入 grant stats、把 NPC id 带入 npc_stats，
  再由 `require_master_id = true` 逐招开启；未配置该键的其它峨眉授艺零影响。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.SectMaster
  alias Kantele.World.InquiryHandlers.SectMasterGrant
  alias Kantele.World.Loader

  @npc_id "clone_lib:emei_fengling"
  @family "峨嵋派"
  @family_deny "我与阁下素无来往，不知阁下打听这个干嘛？"
  @master_deny "只有我的弟子才能学习此招，你还是走吧。"

  setup_all do
    %{world: Loader.load()}
  end

  defp config(world, key) do
    npc =
      Enum.find(world.characters, &(&1.name == "风陵师太")) ||
        raise("风陵师太 not found")

    npc.meta.inquiries[key] || raise("风陵师太/#{key} inquiry not found")
  end

  defp player_stats(opts \\ []) do
    %{
      family: Keyword.get(opts, :family, @family),
      master_id: Keyword.get(opts, :master_id, @npc_id),
      skills: Keyword.get(opts, :skills, %{"force" => 220, "piaoxue-zhang" => 160}),
      gongxian: Keyword.get(opts, :gongxian, 2400),
      shen: Keyword.get(opts, :shen, 50_000),
      max_neili: Keyword.get(opts, :max_neili, 2500),
      performs: MapSet.new()
    }
  end

  defp npc_stats(opts \\ []) do
    %{
      family: Keyword.get(opts, :family, @family),
      id: Keyword.get(opts, :id, @npc_id)
    }
  end

  defp grant_config(opts \\ []) do
    base = %{
      "perform_id" => "piaoxue-zhang/yun",
      "skill" => "piaoxue-zhang",
      "family" => @family,
      "gate_order" => "lpc_emei",
      "min_levels" => %{"force" => 200, "max-neili" => 2000, "piaoxue-zhang" => 150},
      "level_order" => ["force", "max-neili", "piaoxue-zhang"],
      "min_gongxian" => 1800,
      "cost_gongxian" => 1800,
      "min_shen" => 40_000,
      "family_deny" => @family_deny,
      "skill_deny" => "你连飘雪穿云掌都没学，还谈什么绝招可言？",
      "gongxian_deny" => "你对峨嵋派所作出的贡献还不够，这招我暂时不能传你。",
      "shen_deny" => "你行侠仗义的事情还做得不够，我暂时还不能传你此招。"
    }

    case Keyword.get(opts, :require_master_id, true) do
      false -> base
      value -> Map.put(base, "require_master_id", value)
    end
  end

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      vitals: %Vitals{max_neili: 2500},
      stats: %Stats{
        skills: %{"force" => 220, "piaoxue-zhang" => 160},
        gongxian: 2400,
        shen: 50_000,
        performs: MapSet.new()
      },
      family: %{
        name: @family,
        master_id: Keyword.get(opts, :master_id, @npc_id)
      }
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "emei:qingfeng",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp data do
    %{
      asker_id: "player:test",
      npc_id: @npc_id,
      npc_family: @family,
      npc_name: "风陵师太",
      perform_name: "云海明灯"
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: text} -> text
      %Conn.EventText{text: %Conn.Text{data: text}} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  test "风陵两招均配置 require_master_id 与 LPC 原文拒绝文案", %{world: world} do
    for key <- ["云海明灯", "佛光普照"] do
      cfg = config(world, key)

      assert cfg["gate_order"] == "lpc_emei"
      assert cfg["family_deny"] == @family_deny
      assert cfg["require_master_id"] in [true, "true"]
      assert cfg["master_id_deny"] == @master_deny
    end
  end

  test "非同门仍先命中 LPC 原文 family_deny" do
    config = grant_config()

    assert {:error, @family_deny <> "\n"} =
             SectMaster.inquiry_grant(
               player_stats(family: "武当派"),
               npc_stats(),
               config
             )
  end

  test "同门非亲传：master_id 门早于技能存在门与贡献门" do
    config = grant_config()

    assert {:error, @master_deny <> "\n"} =
             SectMaster.inquiry_grant(
               player_stats(
                 master_id: "clone_lib:emei_jingxuan",
                 skills: %{},
                 gongxian: 0
               ),
               npc_stats(),
               config
             )
  end

  test "master_id 缺失不得绕过直传弟子门" do
    config = grant_config()

    assert {:error, @master_deny <> "\n"} =
             SectMaster.inquiry_grant(player_stats(master_id: nil), npc_stats(), config)
  end

  test "NPC id 缺失同样拒绝，不以裸 family 放行" do
    config = grant_config()

    assert {:error, @master_deny <> "\n"} =
             SectMaster.inquiry_grant(player_stats(), npc_stats(id: nil), config)
  end

  test "直传弟子且其余门槛通过：授予绝招并按配置扣贡献" do
    assert {:ok, "piaoxue-zhang/yun", 1800} =
             SectMaster.inquiry_grant(player_stats(), npc_stats(), grant_config())
  end

  test "未开启 require_master_id 的 lpc_emei 授艺保持旧行为" do
    assert {:ok, "piaoxue-zhang/yun", 1800} =
             SectMaster.inquiry_grant(
               player_stats(master_id: "clone_lib:emei_jingxuan"),
               npc_stats(),
               grant_config(require_master_id: false)
             )
  end

  test "handler 把 family.master_id 与 npc_id 带入门控：非亲传不学会", %{world: world} do
    cfg = config(world, "云海明灯")

    result = SectMasterGrant.run(conn(master_id: "clone_lib:emei_jingxuan"), cfg, data())

    assert output_text(result) =~ @master_deny

    character = result.private.update_character || result.character
    refute Stats.perform_known?(character.meta.stats, "piaoxue-zhang/yun")
  end

  test "handler 直传弟子成功学会「云海明灯」", %{world: world} do
    cfg = config(world, "云海明灯")

    result = SectMasterGrant.run(conn(), cfg, data())

    assert output_text(result) =~ "你学会了「云海明灯」。"

    character = result.private.update_character || result.character
    assert Stats.perform_known?(character.meta.stats, "piaoxue-zhang/yun")
  end
end
