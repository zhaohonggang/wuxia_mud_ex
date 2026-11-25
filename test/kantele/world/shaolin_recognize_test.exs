defmodule Kantele.World.ShaolinRecognizeTest do
  @moduledoc """
  #1044：空见/无名 `recognize_apprentice` 的条件分文案门。

  - 空见：同门 + 只教 jingang-buhuaiti + buddhism>=250（否则逐字拒）
  - 无名：同门 + shen>=50000 + 四技能白名单 + strike/unarmed 各自 >179 独立拒文
  - 无名 attempt_apprentice：同门/异门两支不同拒绝文案

  数据读真实 UCL；逻辑直接调 SectMaster/NpcFamilyEvent 的纯函数与事件入口。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.NpcFamilyEvent
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @moduletag :shaolin_recognize

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, key), do: zone_npc(world, "clone_lib", key)

  defp zone_npc(world, zone_id, key) do
    zone = Enum.find(world.zones, &(&1.id == zone_id))
    Map.get(zone.characters || %{}, String.to_atom(key))
  end

  defp student(opts \\ []) do
    family = Keyword.get(opts, :family, "少林派")
    skills = Keyword.get(opts, :skills, %{"buddhism" => 300, "strike" => 100, "unarmed" => 100})

    %{
      meta: %{
        # Kalevala Family.name/1 读 :name（不是 :family_name）
        family: %{name: family, master_name: Keyword.get(opts, :master_name)},
        stats: %{shen: Keyword.get(opts, :shen, 60_000), skills: skills},
        env: %{},
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  describe "UCL 数据" do
    test "空见 recognize 带 buddhism 下限与首次解锁台词", ctx do
      recognize = npc(ctx.world, "shaolin_kong_jian").meta.teach.recognize

      assert recognize.allowed_skills == ["jingang-buhuaiti"]
      assert recognize.min_skill == "buddhism"
      assert recognize.min_skill_level == 250
      assert recognize.min_skill_deny == "唉！你还是好好修习佛法吧，不要耽于武学。"

      unlock =
        get_in(npc(ctx.world, "shaolin_kong_jian").meta.teach.no_teach_unlock, [
          "jingang-buhuaiti"
        ])

      assert unlock.mark == "can_learn/kongjian/jingang-buhuaiti"
      assert unlock.learned == "好吧，我就传你我少林派的护体神功，日后普渡众生，却少不了它。"
    end

    test "无名 recognize 带家族门/侠义门/逐技上限双文案", ctx do
      wuming = npc(ctx.world, "shaolin_wuming")
      recognize = wuming.meta.teach.recognize

      assert recognize.require_family == "少林派"
      assert recognize.min_shen == 50_000
      assert recognize.allowed_skills == ["strike", "rulai-zhang", "unarmed", "ruying-suixingtui"]
      assert recognize.max_skill_levels == %{"strike" => 179, "unarmed" => 179}
      assert recognize.maxed_denies["strike"] == "你的掌法造诣已经非同凡响了，剩下就自己去练吧。"
      assert recognize.maxed_denies["unarmed"] == "你的拳脚功夫已经非同凡响了，剩下就自己去练吧。"

      assert wuming.meta.apprentice.deny_msg_by_family == %{
               "少林派" =>
                 "我早就不收徒弟了，不过你也是我们少林的弟子，就传你一些老僧的粗浅功夫吧！我就教你如影随行腿(ruying-suixingtui)和千手如来掌(rulai-zhang)吧！"
             }
    end
  end

  describe "空见授艺门" do
    test "buddhism<250 逐字拒绝；达标首次解锁并给出 mark", ctx do
      kong = npc(ctx.world, "shaolin_kong_jian")
      low = student(skills: %{"buddhism" => 249})

      assert SectMaster.teachable?(kong, low, "jingang-buhuaiti") ==
               {:error, "唉！你还是好好修习佛法吧，不要耽于武学。\n"}

      assert {:unlock, learned, mark} =
               SectMaster.teachable?(kong, student(), "jingang-buhuaiti")

      assert learned == "好吧，我就传你我少林派的护体神功，日后普渡众生，却少不了它。"
      assert mark == "can_learn/kongjian/jingang-buhuaiti"
    end
  end

  describe "无名授艺门" do
    test "异门/侠义不足/错技能按 LPC 原序逐字拒", ctx do
      wuming = npc(ctx.world, "shaolin_wuming")

      assert SectMaster.teachable?(wuming, student(family: "武当派"), "strike") ==
               {:error, "老衲与阁下素无渊源，何谈传授二字？\n"}

      assert SectMaster.teachable?(wuming, student(shen: 49_999), "strike") ==
               {:error, "我少林派素以普渡众生为根本，你似乎做的还不够。\n"}

      assert SectMaster.teachable?(wuming, student(), "force") ==
               {:error, "我只传授你一些拳脚和掌法的功夫，其它还是找你师父学吧。\n"}
    end

    test "strike/unarmed 各自 >179 使用不同拒绝文案", ctx do
      wuming = npc(ctx.world, "shaolin_wuming")

      assert SectMaster.teachable?(
               wuming,
               student(skills: %{"strike" => 180, "unarmed" => 100}),
               "strike"
             ) == {:error, "你的掌法造诣已经非同凡响了，剩下就自己去练吧。\n"}

      assert SectMaster.teachable?(
               wuming,
               student(skills: %{"strike" => 100, "unarmed" => 180}),
               "unarmed"
             ) == {:error, "你的拳脚功夫已经非同凡响了，剩下就自己去练吧。\n"}

      assert {:unlock, _, "can_learn/wuming"} =
               SectMaster.teachable?(wuming, student(), "rulai-zhang")
    end
  end

  describe "按门派 / born 分文案拒绝" do
    test "同门与异门给出不同拒绝文案", ctx do
      apprentice = npc(ctx.world, "shaolin_wuming").meta.apprentice

      conn = %Conn{
        character: %{name: "无名老僧", meta: %{apprentice: apprentice, teach: nil}},
        private: %Conn.Private{channel_changes: []},
        output: []
      }

      same = %{
        reply_to: self(),
        student_name: "玩家",
        student_family: %{name: "少林派"},
        student_born_family: nil
      }

      NpcFamilyEvent.apprentice(conn, %{data: same})

      assert_receive %Kalevala.Event{
                       topic: "family/result",
                       data: %{
                         ok: false,
                         reason:
                           "我早就不收徒弟了，不过你也是我们少林的弟子，就传你一些老僧的粗浅功夫吧！我就教你如影随行腿(ruying-suixingtui)和千手如来掌(rulai-zhang)吧！"
                       }
                     },
                     200

      other = %{same | student_family: %{name: "武当派"}}
      NpcFamilyEvent.apprentice(conn, %{data: other})

      assert_receive %Kalevala.Event{
                       topic: "family/result",
                       data: %{ok: false, reason: "我只是少林的一名扫地僧，哪里懂什么武功。"}
                     },
                     200
    end

    test "地藏王按 born 有无给出不同拒绝文案", ctx do
      apprentice = zone_npc(ctx.world, "register", "dizangwang").meta.apprentice

      conn = %Conn{
        character: %{name: "地藏王", meta: %{apprentice: apprentice, teach: nil}},
        private: %Conn.Private{channel_changes: []},
        output: []
      }

      no_born = %{reply_to: self(), student_name: "玩家", student_family: nil, student_born_family: nil}
      NpcFamilyEvent.apprentice(conn, %{data: no_born})

      assert_receive %Kalevala.Event{
                       topic: "family/result",
                       data: %{ok: false, reason: "地藏王说道：你快投胎去，在这里瞎搅和什么？"}
                     },
                     200

      with_born = %{no_born | student_born_family: "凡人"}
      NpcFamilyEvent.apprentice(conn, %{data: with_born})

      assert_receive %Kalevala.Event{
                       topic: "family/result",
                       data: %{ok: false, reason: "地藏王说道：滚！给我一边儿去！"}
                     },
                     200
    end
  end
end
