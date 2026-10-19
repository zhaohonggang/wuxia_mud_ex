defmodule Kantele.Combat.PromoterEnvTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills.Performs.BaguaBiao.Xian

  @root "lib/kantele/combat/skills/performs"

  # 选择器：目录下所有声明 `@behaviour Kantele.Combat.Perform` 的文件（715 个）。
  #
  # 早先这里用的是生成器注释 `由 translate_perform.py 生成`，但那个注释在手工重写
  # 招式时会被覆盖掉：728 个 perform 文件里只剩 292 个还带它，于是 436 个招式
  # 长期没进冒烟测试（也正因为如此，下面 @known_broken 里的 20 个崩溃一直没人发现）。
  @behaviour_marker "@behaviour Kantele.Combat.Perform"

  # 已知在「默认角色」下会崩的 perform，按相对路径登记。
  #
  # 这不是 skip 名单，而是**当前真实状态的精确快照**：断言要求「实际崩溃集合 == 本列表」，
  # 所以修好任何一个都会让测试失败并提示从本列表删掉，出现新的崩溃同样会失败。
  # 分组与成因见 docs/session-prompts-npc-actions-continuation.zh-CN.md 续做 50。
  @known_broken ~w(
    luohan_fumogong/powerup.ex
    qianzhu_wandushou/wan.ex
    qianzhu_wandushou/zhugu.ex
    sanwu_shou/kong.ex
    sanwu_shou/zhi.ex
    sanyin_wugongzhao/zhua.ex
    shangqing_jian/qing.ex
    shangqing_jian/zhuo.ex
    shedao_qigong/cui.ex
    shedao_qigong/fei.ex
    shedao_qigong/xian.ex
    tanzhi_shentong/po.ex
    xianglong_zhang/qu.ex
    xuedao_dafa/chi.ex
    xuedao_dafa/shi.ex
    xuedao_dafa/xue.ex
    yinyang_shiertian/powerup.ex
    yunlong_shengong/powerup.ex
    zigai_jian/hui.ex
    zijinbagua_dao/bagua.ex
  )

  defp build_character(stats_overrides \\ %{}, vitals \\ Vitals.new(), combat \\ Combat.new()) do
    stats = struct(Stats.new(), stats_overrides)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "liuxi:lianwuchang",
      meta: %PlayerMeta{vitals: vitals, stats: stats, combat: combat}
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

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn change ->
      match?({:publish, _, %Kalevala.Event{topic: Kalevala.Event.Message}, _, _}, change)
    end)
    |> Enum.map(fn {:publish, _channel, event, _opts, _error} -> event.data.text end)
    |> Enum.join("")
  end

  defp perform_modules do
    Path.wildcard("#{@root}/**/*.ex")
    |> Enum.flat_map(fn path ->
      content = File.read!(path)

      with true <- String.contains?(content, @behaviour_marker),
           [_, mod] <- Regex.run(~r/^defmodule ([A-Za-z0-9_.]+) do/m, content) do
        [{String.replace_prefix(path, @root <> "/", ""), Module.concat([mod])}]
      else
        _ -> []
      end
    end)
  end

  # bagua-biao.xian 的门栈（xian.ex run/1 的 with 链）：
  # 已学绝招 → 有对手 → 空手 → 手持暗器 → strike/throwing 已激发且已准备
  # → 技能等级 → 真气。下面这套 fixture 满足除「等级/真气」外的全部前置，
  # 让各用例只针对自己关心的那一道门。
  defp xian_enemy do
    %{id: "npc-1", pid: self(), name: "李四", room_id: "liuxi:lianwuchang"}
  end

  # handing_anqi/1 的识别条件：inventory 中 meta 带 handing + skill_type
  # == "throwing" 且 amount >= 1。
  defp xian_anqi do
    %Kalevala.World.Item{
      id: "test:anqi",
      name: "铁菩提",
      meta: %{handing: true, skill_type: "throwing", amount: 10}
    }
  end

  defp xian_character(skills, vitals \\ Vitals.new()) do
    combat = %{Combat.new() | enemies: [xian_enemy()]}

    character =
      build_character(
        %{
          skills: skills,
          mapped: %{"strike" => "bagua-zhang", "throwing" => "bagua-biao"},
          prepared: %{"strike" => "bagua-zhang/xian", "throwing" => "bagua-biao/xian"},
          performs: MapSet.new(["bagua-biao/xian"])
        },
        vitals,
        combat
      )

    %{character | inventory: [xian_anqi()]}
  end

  test "所有 perform 模块在游戏环境中的崩溃集合与已知名单一致（默认角色）" do
    mods = perform_modules()
    assert length(mods) > 500

    failures =
      Enum.flat_map(mods, fn {path, mod} ->
        try do
          if Code.ensure_loaded?(mod) do
            conn = mod.run(build_conn(build_character()))

            if match?(%Kalevala.Character.Conn{}, conn) do
              []
            else
              [{path, :not_a_conn}]
            end
          else
            [{path, :not_loaded}]
          end
        rescue
          e -> [{path, {e.__struct__, Exception.message(e)}}]
        end
      end)

    actual = failures |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    expected = Enum.sort(@known_broken)

    if actual != expected do
      IO.puts("perform 冒烟失败 #{length(failures)} 个：")
      Enum.each(failures, fn {p, r} -> IO.puts("  #{p} -> #{inspect(r)}") end)
    end

    assert actual == expected, """
    perform 崩溃集合与 @known_broken 不一致。
      新增崩溃（需要修）：#{inspect(actual -- expected)}
      已修好（请从 @known_broken 删掉）：#{inspect(expected -- actual)}
    """
  end

  test "perform bagua-biao.xian：门槛满足时消耗暗器并发布文案" do
    vitals = %{Vitals.new() | neili: 1000}

    character =
      xian_character(
        %{"bagua-biao" => 130, "bagua-zhang" => 130, "force" => 160},
        vitals
      )

    conn = Xian.run(build_conn(character))

    updated = conn.private.update_character
    assert published_text(conn) =~ "突然只听张三"

    # LPC: if (anqi->query_amount() > 0) anqi->add_amount(-1);
    assert [anqi] = updated.inventory
    assert anqi.meta.amount == 9

    # LPC 的 me->add("neili", -100) 位于命中分支内，本引擎按
    # 「攻击方投递事件 → 目标侧结算 → combat/perform-feedback 回执」
    # 的架构，把内力扣减放到目标侧 resolve_incoming 里
    # （见 xian.ex do_resolve_incoming/4 的 Performs.feedback(attacker, 100, 3)）。
    # 因此 run/1 本身不扣内力，此处保持不变；扣减由 feedback 链路负责。
    assert updated.meta.vitals.neili == 1000
  end

  test "perform bagua-biao.xian：等级不足时拒绝" do
    character = xian_character(%{"bagua-biao" => 10, "bagua-zhang" => 10, "force" => 10})

    conn = Xian.run(build_conn(character))

    assert output_text(conn) =~ "你的八卦掌不够娴熟"
  end

  test "exert hamagong.hui：已倒转经脉时把内力清空" do
    vitals = %{Vitals.new() | neili: 1000}

    # LPC hui.c:97 `if (! (skill = me->query_temp("hmg_dzjm")))
    #                  return notify_fail("你并没有倒转经脉啊。\n");`
    # 「经脉倒转」（reserve）是硬前置，本引擎折算为 buff，缺则直接拒绝。
    combat = %{
      Combat.new()
      | buffs: [%Kantele.Character.Combat.Buff{key: "hmg_dzjm", applies: %{}}]
    }

    character = build_character(%{skills: %{"hamagong" => 200}}, vitals, combat)

    conn = Kantele.Combat.Skills.Performs.Hamagong.Hui.run(build_conn(character))

    updated = conn.private.update_character
    assert updated.meta.vitals.neili == 0
  end

  test "exert hamagong.hui：未倒转经脉时拒绝" do
    character = build_character(%{skills: %{"hamagong" => 200}})

    conn = Kantele.Combat.Skills.Performs.Hamagong.Hui.run(build_conn(character))

    assert output_text(conn) =~ "你并没有倒转经脉"
    assert conn.private.update_character == nil
  end
end
