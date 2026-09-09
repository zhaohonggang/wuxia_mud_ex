defmodule Kantele.Quest.ChainWalkTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.QuestEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Quest

  # 周不通七步链（与 data/world/liuxi.ucl butong 配置的 chain 一致）：
  # 打铁20 → 存钱 → 买包子 → 郭府 → 拜师 → 祈福 → 师门5
  @files ~w(_0_tutorial_datie _0_tutorial_cunqian _0_tutorial_baozi _0_tutorial_guofu _0_tutorial_baishi _0_tutorial_qifu _0_tutorial_shimen5)

  defp steps() do
    Enum.with_index(@files)
    |> Enum.map(fn {file, idx} ->
      %{
        file: file,
        type: "chain",
        level: 1,
        limit: 1800,
        repeatable: false,
        master_name: "周不通",
        master_id: "liuxi:butong",
        chain: Enum.take(@files, idx)
      }
    end)
  end

  # 一脚一清：标记已解 + 从在办移除 + 连续计数 +1（映射 quest_event.update_quests）
  defp complete(state, %{file: file}) do
    {:ok, s} = Quest.set_solved(state, %{file: file})

    s
    |> Quest.del_todo(file)
    |> Quest.bump_quest_count()
  end

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: 50
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

  test "链式前置：未解前步拒绝，解后开放" do
    [step1, step2 | _] = steps()

    assert {:ok, s1} = Quest.set_todo(Quest.new(), step1)
    assert {:error, :chain_blocked} = Quest.set_todo(s1, step2)
    refute Quest.chain_open?(s1, step2)

    s1 = complete(s1, step1)
    assert Quest.chain_open?(s1, step2)
    assert {:ok, _s2} = Quest.set_todo(s1, step2)
  end

  test "七步链一步一清全部解锁（打铁→师门5）" do
    result =
      Enum.reduce_while(steps(), Quest.new(), fn spec, state ->
        case Quest.set_todo(state, spec) do
          {:ok, next} -> {:cont, complete(next, spec)}
          {:error, reason} -> {:halt, {:error, reason, spec.file}}
        end
      end)

    assert result |> Quest.get_solved() == @files
    assert result |> Quest.quest_count() == 7
  end

  test "链务不可重复：已解后不再接" do
    [step | _] = steps()
    state = steps() |> Enum.reduce(Quest.new(), &complete(&2, &1))

    assert {:error, :done} = Quest.set_todo(state, step)
  end

  test "QuestEvent 拒绝链未解任务：提示先办前事（chain_blocked 文案）" do
    [_, step2 | _] = steps()
    p = player()

    conn =
      QuestEvent.ask_result(build_conn(p), %Event{
        topic: "quest/ask-result",
        data: %{ok: true, npc_name: "周不通", quest: step2}
      })

    assert output_text(conn) =~ "前头的差事办妥"
    assert conn.private.update_character == nil
  end

  test "QuestEvent 接受链已解步骤并入 todo" do
    [step1, step2 | _] = steps()
    state = complete(Quest.new(), step1)
    p = %{player() | meta: PlayerMeta.put_quests(player().meta, state)}
    assert %{solved: ["_0_tutorial_datie"]} = p.meta.quests

    conn =
      QuestEvent.ask_result(build_conn(p), %Event{
        topic: "quest/ask-result",
        data: %{ok: true, npc_name: "周不通", quest: step2}
      })

    updated = conn.private.update_character || conn.character
    assert Quest.get_todo(updated.meta.quests, step2.file)
    refute Quest.get_solved(updated.meta.quests) |> Enum.member?(step2.file)
  end
end