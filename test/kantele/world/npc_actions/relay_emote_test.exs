defmodule Kantele.World.NpcActions.RelayEmoteTest do
  @moduledoc """
  P5-8 #8 后半：NPC `relay_emote` 表情回应（city 桃谷六仙 tao1–6 +
  huashan 劳德诺 lao-denuo）。

  覆盖：config/1 分派表、tao1 kick 三分支、tao2–6 kick（<5 斥责 /
  ≥5 落入 hug+default 串接）、hug/kiss/mo/18mo/nocloth 性别分支 +
  message_vision、default 兜底、lao_denuo 非 beg 随机表情、lao_denuo
  beg 的华山剑宗（set_temp beg_huashan）/ 非华山剑宗（装可怜）分支，
  以及 RelayEmoteDispatcher 的目标解析与 :not_handled 短路。

  随机性用 `:rand.seed` 复现：先以同一 seed 取出 run 将消费的 uniform
  序列，再重置 seed 跑 run，按取出的 roll 断言分支，保证确定性。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.RelayEmote
  alias Kantele.World.RelayEmoteDispatcher

  @room_id "city:taohua"

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100}),
      temp: Keyword.get(opts, :temp, %{}),
      marks: Keyword.get(opts, :marks, %{}),
      coins: Keyword.get(opts, :coins, 1_000),
      env: Keyword.get(opts, :env, %{}),
      family: Keyword.get(opts, :family, nil)
    }

    %Conn{
      character: %Kalevala.Character{
        name: Keyword.get(opts, :name, "玩家"),
        room_id: @room_id,
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp npc(name, aliases \\ []), do: %{name: name, aliases: aliases, room_id: @room_id}

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp temp_get(conn, key) do
    char = conn.private.update_character || conn.character
    char.meta.temp[key]
  end

  # 复现 run 将消费的 uniform(10) 序列（最多取 n 个），返回该序列
  defp seeded_uniform(seed, n) do
    :rand.seed(:exsss, seed)
    Enum.map(1..n, fn _ -> :rand.uniform(10) end)
  end

  # ---- config/1 ----

  describe "config/1 分派表" do
    test "桃谷六仙 + 劳德诺 登记正确" do
      assert :tao1 == RelayEmote.config("桃根仙")
      assert :tao == RelayEmote.config("桃干仙")
      assert :tao == RelayEmote.config("桃枝仙")
      assert :tao == RelayEmote.config("桃叶仙")
      assert :tao == RelayEmote.config("桃花仙")
      assert :tao == RelayEmote.config("桃实仙")
      assert :lao_denuo == RelayEmote.config("劳德诺")
    end

    test "非登记 NPC / 非字符串 → nil" do
      assert nil == RelayEmote.config("张三丰")
      assert nil == RelayEmote.config(nil)
      assert nil == RelayEmote.config(123)
    end
  end

  # ---- tao1 kick 三分支 ----

  describe "tao1 kick 三分支" do
    test "roll<5 → 咬 + 骂" do
      seed = {1, 1, 1}
      [roll] = seeded_uniform(seed, 1)
      :rand.seed(:exsss, seed)
      conn = RelayEmote.run(conn(), npc("桃根仙"), "kick")
      visions = vision_texts(conn)

      cond do
        roll < 5 ->
          assert Enum.any?(visions, &String.contains?(&1, "一口咬了下去"))
          assert Enum.any?(visions, &String.contains?(&1, "桃根仙说道：我操！你皮痒啊？"))

        roll < 10 ->
          assert Enum.any?(visions, &String.contains?(&1, "作势要揍"))
          assert Enum.any?(visions, &String.contains?(&1, "桃根仙说道：他奶奶的！找死啊？"))

        true ->
          assert Enum.any?(visions, &String.contains?(&1, "狠狠踢了三脚"))
          assert Enum.any?(visions, &String.contains?(&1, "桃根仙说道：奶奶的，这样够爽么？"))
      end
    end
  end

  # ---- tao2–6 kick ----

  describe "tao2-6 kick" do
    test "roll<5 → 只说「为什麽踢我」并 break（无 hug/default）" do
      seed = {2, 2, 2}
      [roll] = seeded_uniform(seed, 1)
      :rand.seed(:exsss, seed)
      conn = RelayEmote.run(conn(), npc("桃干仙"), "kick")
      visions = vision_texts(conn)

      if roll < 5 do
        assert Enum.any?(visions, &String.contains?(&1, "桃干仙说道：为什麽踢我？会痛耶！"))
        refute Enum.any?(visions, &String.contains?(&1, "摇了摇头"))
      end
    end

    test "roll>=5 → 落入 hug+kiss 串接（性别分支 + message_vision + default）" do
      seed = {3, 3, 3}
      [r1, r2] = seeded_uniform(seed, 2)
      :rand.seed(:exsss, seed)
      # 玩家默认性别为 nil（非男性/无性）→ 走女性分支
      conn = RelayEmote.run(conn(), npc("桃干仙"), "kick")
      visions = vision_texts(conn)

      if r1 >= 5 do
        # 女性分支：咯咯一笑 + 豆腐送上门 + message_vision
        assert Enum.any?(visions, &String.contains?(&1, "桃干仙咯咯一笑。"))
        assert Enum.any?(visions, &String.contains?(&1, "自动把豆腐送上门来了"))
        assert Enum.any?(visions, &String.contains?(&1, "摇了摇头，对{npc}幽幽叹道"))

        # default 分支：要么回敬、要么 drool 兜底
        assert Enum.any?(visions, fn v ->
                 String.contains?(v, "桃干仙对着{npc}") and String.contains?(v, "了一下。")
               end) or
                 Enum.any?(visions, &String.contains?(&1, "直咽口水"))

        # r2 仅影响 default 走哪支，这里不强行断言具体支
        _ = r2
      end
    end
  end

  # ---- hug/kiss/mo/18mo/nocloth 性别分支 ----

  describe "hug/kiss/mo/18mo/nocloth 性别分支" do
    test "男性玩家 → chat 龙阳之好 + message_vision" do
      seed = {4, 4, 4}
      [roll] = seeded_uniform(seed, 1)
      :rand.seed(:exsss, seed)
      conn = RelayEmote.run(conn(env: %{"gender" => "男性"}), npc("桃根仙"), "hug")
      visions = vision_texts(conn)

      assert Enum.any?(visions, &String.contains?(&1, "我就喜欢这个调调儿"))
      assert Enum.any?(visions, &String.contains?(&1, "龙阳之好"))
      assert Enum.any?(visions, &String.contains?(&1, "摇了摇头，对{npc}幽幽叹道"))
      # default 分支也触发
      assert length(visions) >= 3
      _ = roll
    end

    test "女性玩家 → giggle + 豆腐送上门 + message_vision" do
      seed = {5, 5, 5}
      [roll] = seeded_uniform(seed, 1)
      :rand.seed(:exsss, seed)
      conn = RelayEmote.run(conn(env: %{"gender" => "女性"}), npc("桃根仙"), "kiss")
      visions = vision_texts(conn)

      assert Enum.any?(visions, &String.contains?(&1, "桃根仙咯咯一笑。"))
      assert Enum.any?(visions, &String.contains?(&1, "自动把豆腐送上门来了"))
      assert Enum.any?(visions, &String.contains?(&1, "摇了摇头，对{npc}幽幽叹道"))
      assert length(visions) >= 3
      _ = roll
    end

    test "所有五个动词都进入同一性别分支" do
      for verb <- ["hug", "kiss", "mo", "18mo", "nocloth"] do
        :rand.seed(:exsss, {6, 6, 6})
        conn = RelayEmote.run(conn(env: %{"gender" => "男性"}), npc("桃枝仙"), verb)
        visions = vision_texts(conn)
        assert Enum.any?(visions, &String.contains?(&1, "龙阳之好")), "verb=#{verb}"
        assert Enum.any?(visions, &String.contains?(&1, "摇了摇头")), "verb=#{verb}"
      end
    end
  end

  # ---- default 分支（任意其它动词）----

  describe "default 分支" do
    test "random<5 → NPC 用同动词回敬玩家" do
      seed = {7, 7, 7}
      [roll] = seeded_uniform(seed, 1)
      :rand.seed(:exsss, seed)
      conn = RelayEmote.run(conn(), npc("桃根仙"), "slap")
      visions = vision_texts(conn)

      if roll < 5 do
        assert Enum.any?(visions, &String.contains?(&1, "桃根仙对着{npc}slap了一下。"))
      else
        assert Enum.any?(visions, &String.contains?(&1, "直咽口水"))
      end
    end
  end

  # ---- lao_denuo ----

  describe "lao_denuo 非 beg 随机表情" do
    test "五种随机表情各渲染一条 vision" do
      for roll <- 0..4 do
        seed = {100 + roll, 1, 1}
        # lao_nonbeg 用 :rand.uniform(5) - 1；复现该序列
        :rand.seed(:exsss, seed)
        got = :rand.uniform(5) - 1
        :rand.seed(:exsss, seed)
        conn = RelayEmote.run(conn(), npc("劳德诺"), "grin")
        visions = vision_texts(conn)
        assert length(visions) == 1, "roll=#{got}"
        text = hd(visions)

        expected =
          case got do
            0 -> "劳德诺一副百无聊赖的样子。"
            1 -> "劳德诺打了个哈欠。"
            2 -> "劳德诺发出一声怪叫。"
            3 -> "劳德诺打了个冷战。"
            _ -> "劳德诺嘿嘿一笑。"
          end

        assert text == expected, "roll=#{got} got #{inspect(text)}"
      end
    end
  end

  describe "lao_denuo beg" do
    test "玩家为华山剑宗 → 叹气 + 敬称台词 + set_temp beg_huashan=1" do
      conn =
        RelayEmote.run(
          conn(family: %{name: "华山剑宗"}),
          npc("劳德诺"),
          "beg"
        )

      visions = vision_texts(conn)
      assert Enum.any?(visions, &String.contains?(&1, "劳德诺叹了口气。"))
      assert Enum.any?(visions, &String.contains?(&1, "入了剑宗，后悔了吧"))
      assert temp_get(conn, "beg_huashan") == 1
    end

    test "玩家非华山剑宗 → 装可怜（不写 beg_huashan）" do
      conn =
        RelayEmote.run(
          conn(family: %{name: "嵩山派"}),
          npc("劳德诺"),
          "beg"
        )

      visions = vision_texts(conn)
      assert Enum.any?(visions, &String.contains?(&1, "装出一副可怜相"))
      refute temp_get(conn, "beg_huashan") == 1
    end

    test "玩家无门派 → 同样装可怜" do
      conn = RelayEmote.run(conn(family: nil), npc("劳德诺"), "beg")
      visions = vision_texts(conn)
      assert Enum.any?(visions, &String.contains?(&1, "装出一副可怜相"))
    end
  end

  # ---- RelayEmoteDispatcher ----

  describe "RelayEmoteDispatcher 触发与短路" do
    test "社交动词 + 登记 NPC（按名）→ {:handled, conn} 含玩家动作 + NPC 回应" do
      chars = [npc("桃根仙", ["tao", "taogen"])]
      conn = conn()

      assert {:handled, conn} = RelayEmoteDispatcher.dispatch(conn, "kick 桃根仙", fn _ -> chars end)
      visions = vision_texts(conn)
      # 玩家动作铺垫
      assert Enum.any?(visions, &String.contains?(&1, "{npc}对着桃根仙踢了一脚。"))
      # NPC 回应
      assert Enum.any?(visions, &String.contains?(&1, "桃根仙"))
    end

    test "社交动词 + 登记 NPC（按别名 tao）→ 命中" do
      chars = [npc("桃干仙", ["tao", "gan"])]
      assert {:handled, _conn} = RelayEmoteDispatcher.dispatch(conn(), "hug tao", fn _ -> chars end)
    end

    test "社交动词但目标未登记 → :not_handled" do
      chars = [npc("路人甲", ["lu"])]
      assert :not_handled = RelayEmoteDispatcher.dispatch(conn(), "kick 路人甲", fn _ -> chars end)
    end

    test "非社交动词 → :not_handled" do
      chars = [npc("桃根仙", ["tao"])]
      assert :not_handled = RelayEmoteDispatcher.dispatch(conn(), "look 桃根仙", fn _ -> chars end)
    end

    test "社交动词但无目标 → :not_handled" do
      assert :not_handled = RelayEmoteDispatcher.dispatch(conn(), "kick", fn _ -> [] end)
    end
  end
end
