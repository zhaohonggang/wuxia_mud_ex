defmodule Kantele.World.RoomActions.Huashan.ChaoyangTest do
  @moduledoc """
  P5-9 #9 一次性场景：华山朝阳峰「拉青藤 / 跳崖」（移植自
  `d/huashan/chaoyang.c` 的 `do_la` + `do_jump`）。

  分层测试：
  1. **注册表**：`huashan:chaoyang` 的 `la`/`jump` → `Chaoyang`；非本房 / 未知动词 /
     无角色上下文 → `:not_handled`。
  2. **la**：错参 / 忙 / 战斗中 / 已拉住 / 成功（vision + `temp.la_teng_huashan` +
     `start_busy(2)`）。
  3. **jump**：错参 / 忙 / 无藤且 `dex<30`（摔死：qi=jing=1 + ghost + 不进金蛇洞）/
     无藤但 `dex>=30`（成功）/ 有藤（成功，藤优先于轻功）。
  4. **整链**：`la teng` → `jump ya` 进金蛇洞，藤标记被清。

  注：本房间**不读写房 state**，故不需要 FakeRoom；`Helpers.move_to/2` 与
  `RoomActions.Break.die/1` 都只走 conn 本地原语（`Teleport.teleport` 的
  move/subscribe 均写 `conn.private.channel_changes`）。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Huashan.Chaoyang

  @room "huashan:chaoyang"
  @jinshedong "huashan:jinshedong"

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "la / jump 都指向 Chaoyang" do
      assert RoomActionHandlers.lookup(@room, "do_la") == {:ok, {Chaoyang, :run}}
      assert RoomActionHandlers.lookup(@room, "do_jump") == {:ok, {Chaoyang, :run}}
    end

    test "非本房 → :not_handled" do
      conn = conn(room_id: "huashan:lianhua")

      assert Chaoyang.run(conn, %{verb: "do_la", trailing: "teng", room_id: "huashan:lianhua"}) ==
               :not_handled
    end

    test "未知动词 → :not_handled" do
      assert Chaoyang.run(conn(), %{verb: "do_climb", trailing: "", room_id: @room}) ==
               :not_handled
    end

    test "无角色上下文 → :not_handled" do
      assert Chaoyang.run(%Conn{}, %{verb: "do_la", trailing: "teng", room_id: @room}) ==
               :not_handled
    end
  end

  # ---- la -------------------------------------------------------------------

  describe "la" do
    test "无参 → 你要拉什么" do
      assert output(run("do_la", "")) == "你要拉什么？\n"
    end

    test "错参（ya 不是 teng）→ 你要拉什么" do
      assert output(run("do_la", "ya")) == "你要拉什么？\n"
    end

    test "忙 → 等你忙完了再说吧" do
      assert output(run("do_la", "teng", conn(busy: 2))) == "等你忙完了再说吧！\n"
    end

    test "战斗中 → 等你忙完了再说吧" do
      assert output(run("do_la", "teng", conn(fighting: true))) == "等你忙完了再说吧！\n"
    end

    test "已拉住 → 你已经拉住青藤了" do
      c = conn(temp: %{"la_teng_huashan" => 1})

      assert output(run("do_la", "teng", c)) == "你已经拉住青藤了。\n"
    end

    test "成功 → vision「将青藤牢牢地抓住了」+ 记 temp + busy 2" do
      result = run("do_la", "teng")

      assert published(result) == ["{npc}将青藤牢牢地抓住了。\n"]
      assert character_of(result).meta.temp["la_teng_huashan"] == 1
      assert character_of(result).meta.combat.busy == 2
    end

    test "前导/尾随空白被 trim（`la  teng ` 同样成立）" do
      result = run("do_la", "  teng  ")

      assert character_of(result).meta.temp["la_teng_huashan"] == 1
    end
  end

  # ---- jump -----------------------------------------------------------------

  describe "jump" do
    test "无参 → 你要往哪儿跳" do
      assert output(run("do_jump", "")) == "你要往哪儿跳？\n"
    end

    test "错参（teng 不是 ya）→ 你要往哪儿跳" do
      assert output(run("do_jump", "teng")) == "你要往哪儿跳？\n"
    end

    test "忙 → 等你忙完了再说吧" do
      assert output(run("do_jump", "ya", conn(busy: 1))) == "等你忙完了再说吧！\n"
    end

    test "战斗中 → 等你忙完了再说吧" do
      assert output(run("do_jump", "ya", conn(fighting: true))) == "等你忙完了再说吧！\n"
    end

    test "没拉藤且 dex<30 → 摔死（qi=jing=1、进幽灵态、不进金蛇洞）" do
      result = run("do_jump", "ya", conn(dex: 0))

      assert published(result) == ["{npc}纵身跳下悬崖 ……\n"]

      c = character_of(result)
      assert c.meta.vitals.qi == 1
      assert c.meta.vitals.jing == 1
      assert c.meta.damage[:ghost] == true
      refute c.room_id == @jinshedong
    end

    test "没拉藤但 dex>=30 → 轻功够，成功进金蛇洞" do
      result = run("do_jump", "ya", conn(dex: 40))

      assert published(result) == ["{npc}拉着青藤跳下悬崖……\n"]
      assert String.contains?(output(result), "猛然间，你发现下面有一个小洞")

      c = character_of(result)
      assert c.room_id == @jinshedong
      assert c.meta.combat.busy == 2
      # 本来就没藤，删了也是空
      assert Map.get(c.meta.temp, "la_teng_huashan") == nil
      # 没死
      assert c.meta.vitals.qi == 100
    end

    test "拉了藤（dex<30 也）→ 成功进金蛇洞、藤标记清除" do
      c = conn(temp: %{"la_teng_huashan" => 1}, dex: 0)

      result = run("do_jump", "ya", c)

      assert published(result) == ["{npc}拉着青藤跳下悬崖……\n"]

      ch = character_of(result)
      assert ch.room_id == @jinshedong
      assert Map.get(ch.meta.temp, "la_teng_huashan") == nil
      assert ch.meta.combat.busy == 2
      # 没死
      assert ch.meta.vitals.qi == 100
    end
  end

  # ---- 整链 -----------------------------------------------------------------

  describe "整链" do
    test "la teng → jump ya：先抓住藤，再跳进金蛇洞" do
      # `la` 会 start_busy(2)，直接紧跟 jump 会被忙乱拦截；此处用新 conn
      # 保留 temp.la_teng_huashan 但 busy=0，验证 jump 本身的逻辑
      c = conn(temp: %{"la_teng_huashan" => 1})

      result = run("do_jump", "ya", c)

      assert published(result) == ["{npc}拉着青藤跳下悬崖……\n"]
      assert character_of(result).room_id == @jinshedong
      assert Map.get(character_of(result).meta.temp, "la_teng_huashan") == nil
      assert character_of(result).meta.combat.busy == 2
    end
  end

  # ---- helpers --------------------------------------------------------------

  # 每条命令都是独立一次输入：清掉上一条命令的 output / channel_changes，
  # 只保留 private.update_character 里累积的角色状态。
  defp run(verb, trailing, conn \\ nil) do
    conn = conn || conn()

    conn = %{conn | output: [], private: %{conn.private | channel_changes: []}}

    case Chaoyang.run(conn, %{verb: verb, trailing: trailing, room_id: @room}) do
      {:handled, conn2} -> conn2
      other -> other
    end
  end

  defp conn(opts \\ []) do
    dex = Keyword.get(opts, :dex, 0)

    combat = %Combat{
      busy: Keyword.get(opts, :busy, 0),
      enemies: if(Keyword.get(opts, :fighting, false), do: [%{id: "npc:test", name: "对手"}], else: [])
    }

    %Conn{
      character: %Kalevala.Character{
        id: Keyword.get(opts, :id, "player:chaoyang_test"),
        name: Keyword.get(opts, :name, "张三"),
        room_id: Keyword.get(opts, :room_id, @room),
        meta: %PlayerMeta{
          temp: Keyword.get(opts, :temp, %{}),
          coins: 0,
          # query_dex 会读 stats.skills（Map.get(nil, ...) 会崩），故必须给 %{}
          stats: %Stats{dex: dex, skills: %{}},
          vitals: %Vitals{qi: 100, max_qi: 100, jing: 100, max_jing: 100},
          combat: combat
        },
        inventory: []
      },
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end
end
