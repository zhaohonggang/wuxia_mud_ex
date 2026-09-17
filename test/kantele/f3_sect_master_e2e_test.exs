defmodule Kantele.F3SectMasterE2ETest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.DetachEvent
  alias Kantele.Character.FamilyEvent
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.NpcFamilyEvent
  alias Kantele.Character.NpcScriptEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SkillsEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Loader

  setup_all do
    yu = Loader.load().characters |> Enum.find(&String.contains?(&1.name, "俞莲舟"))
    assert yu != nil
    %{yu: yu}
  end

  test "F3 数据驱动师父 e2e：拜师门槛→拜师→学艺→问答得绝招→叛师惩罚", %{yu: yu} do
      # 1. NPC 按自身 UCL 配置回执（不自行判定）
      NpcFamilyEvent.apprentice(build_conn(yu), %Event{
        topic: "family/apprentice",
        data: %{reply_to: self(), student_name: "张三"}
      })

      assert_receive %Event{topic: "family/result", data: recruit}
      assert recruit.ok == true
      assert recruit.family == "武当派"
      assert recruit.apprentice.min_shen == 20_000
      assert recruit.apprentice.min_exp == 150_000
      assert recruit.apprentice.class == "taoist"

      # 2. 门槛拦：杀气不足
      weak =
        player(
          stats: %{
            shen: 100,
            combat_exp: 200_000,
            skills: %{"wudang-xinfa" => 90, "taoism" => 90}
          }
        )

      conn = FamilyEvent.result(build_conn(weak), %Event{topic: "family/result", data: recruit})
      assert conn.private.update_character == nil
      assert output_text(conn) =~ "杀气不足"

      # 3. 达标拜师：写入 family 并继承 class
      pupil =
        player(
          stats: %{
            shen: 30_000,
            combat_exp: 200_000,
            skills: %{"wudang-xinfa" => 90, "taoism" => 90},
            gongxian: 500
          }
        )

      conn = FamilyEvent.result(build_conn(pupil), %Event{topic: "family/result", data: recruit})
      enrolled = conn.private.update_character || conn.character
      enrolled_family = enrolled.meta.family
      assert enrolled_family.name == "武当派"
      assert enrolled_family.class == "taoist"
      assert is_binary(enrolled_family.master_id)

      # 4. 学艺：俞莲舟授基本内功（门派门槛走 SectMaster.teachable?）
      SkillsEvent.teach(build_conn(yu), %Event{
        topic: "skills/teach",
        data: %{
          skill: "force",
          times: 1,
          student_stats: pupil.meta.stats,
          reply_to: self()
        }
      })

      assert_receive %Event{topic: "skills/learn-result", data: %{skill: "force"}}

      # 5. 问答得绝招：ask「绝户神抓」→ npc/perform → 玩家侧 inquiry_grant 落库
      NpcAskEvent.call(build_conn(yu), %Event{
        topic: "characters/ask",
        data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: "绝户神抓"}
      })

      assert_receive %Event{topic: "npc/perform", data: %{npc_family: "武当派"} = perform_data}

      grantee =
        player(
          stats: %{
            shen: 100_000,
            gongxian: 500,
            skills: %{"force" => 180, "huzhua-shou" => 120}
          },
          family: enrolled_family
        )

      conn = NpcScriptEvent.perform_result(build_conn(grantee), %Event{
        topic: "npc/perform",
        data: perform_data
      })

      learned = conn.private.update_character || conn.character
      assert MapSet.member?(learned.meta.stats.performs, "huzhua-shou/juehu")
      assert learned.meta.stats.gongxian == 100

      # 6. 叛师惩罚：同门嫡传 → 武功降一重、贡献归零、门派清空
      conn = DetachEvent.detach_result(build_conn(grantee), %Event{
        topic: "family/detach-result",
        data: %{
          ok: true,
          family: enrolled_family.name,
          master_id: enrolled_family.master_id,
          master_name: enrolled_family.master_name
        }
      })

      detached = conn.private.update_character || conn.character
      assert detached.meta.family == nil
      assert detached.meta.stats.gongxian == 0
      assert output_text(conn) =~ "叛离了师门"
  end

  defp player(opts) do
    stats = struct(Stats.new(), Keyword.get(opts, :stats, %{}))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        family: Keyword.get(opts, :family)
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
