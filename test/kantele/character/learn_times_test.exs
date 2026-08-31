defmodule Kantele.Character.LearnTimesTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.LearnCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SkillsEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  describe "LearnCommand xN 解析" do
    test "剥离 xN 并随事件携带次数" do
      conn =
        LearnCommand.run(build_conn(student(3)), %{
          "skill" => "sword",
          "name" => "王重九 x10"
        })

      event = find_event(conn, "skills/learn")

      assert event.data.name == "王重九"
      assert event.data.times == 10
    end

    test "多余的 xN 以最后一个为准" do
      conn =
        LearnCommand.run(build_conn(student(3)), %{
          "skill" => "sword",
          "name" => "王重九 x2 x2"
        })

      event = find_event(conn, "skills/learn")

      assert event.data.name == "王重九"
      assert event.data.times == 2
    end

    test "无 xN 时默认一次，超上限被钳制" do
      conn =
        LearnCommand.run(build_conn(student(3)), %{
          "skill" => "sword",
          "name" => "王重九 x999"
        })

      event = find_event(conn, "skills/learn")
      assert event.data.times == SkillsEvent.max_times()

      conn1 = LearnCommand.run(build_conn(student(3)), %{"skill" => "sword", "name" => "王重九"})

      assert find_event(conn1, "skills/learn").data.times == 1
    end
  end

  describe "师父侧按师生差距钳制" do
    test "差距不足请求次数时只授差距级数" do
      teacher = teacher(10)
      student_stats = Stats.new() |> Map.put(:skills, %{"sword" => 3}) |> Map.put(:potential, 100)

      SkillsEvent.teach(build_conn(teacher), %{
        topic: "skills/teach",
        data: %{
          skill: "sword",
          times: 20,
          student_stats: student_stats,
          reply_to: self()
        }
      })

      assert_receive %Event{topic: "skills/learn-result", data: %{times: 7, skill: "sword"}}
    end
  end

  describe "学生侧批量学习" do
    test "连学多级：记入 learned_points 池、等级连升、文案带 ×N" do
      # 可用潜能 8（potential 8 - learned_points 0），请求 3 次 × 每级 2
      character = student_with_potential(8, 0)

      conn =
        SkillsEvent.learn_result(build_conn(character), %{
          topic: "skills/learn-result",
          data: %{skill: "sword", times: 3}
        })

      character = current_character(conn)
      stats = character.meta.stats

      assert Stats.skill(stats, "sword") == 3
      # b1：potential 不动，消耗累计到 learned_points；可用余额 8-6=2
      assert stats.potential == 8
      assert stats.learned_points == 6
      assert Stats.available_potential(stats) == 2
      assert output_text(conn) =~ "×3"
    end

    test "潜能中途耗尽即停" do
      # 可用 5 只够 2 级（花 4），请求 5 次 → 学 2 级剩 1
      character = student_with_potential(5, 0)

      conn =
        SkillsEvent.learn_result(build_conn(character), %{
          topic: "skills/learn-result",
          data: %{skill: "sword", times: 5}
        })

      character = current_character(conn)
      stats = character.meta.stats

      assert Stats.skill(stats, "sword") == 2
      assert stats.learned_points == 4
      assert Stats.available_potential(stats) == 1
      assert output_text(conn) =~ "×2"
    end
  end

  # ---- helpers ----

  defp find_event(conn, topic) do
    Enum.find(conn.events, fn event ->
      match?(%Event{topic: ^topic}, event)
    end)
  end

  defp student(sword_level) do
    stats =
      Stats.new()
      |> Map.put(:skills, %{"sword" => sword_level})
      |> Map.put(:potential, 50)

    base_character()
    |> Map.put(:meta, %PlayerMeta{
      vitals: Vitals.new(),
      stats: stats,
      combat: Kantele.Character.Combat.new()
    })
  end

  defp student_with_potential(potential, sword_level) do
    student(sword_level)
    |> Map.update!(:meta, &Map.put(&1, :stats, Map.put(&1.stats, :potential, potential)))
  end

  defp teacher(sword_level) do
    base_character()
    |> Map.put(:name, "王重九")
    |> Map.put(:id, "npc-wang")
    |> Map.put(:meta, %PlayerMeta{stats: Map.put(Stats.new(), :skills, %{"sword" => sword_level})})
  end

  defp base_character do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room"
    }
  end

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
