defmodule Kantele.World.Trap.ShaolinGate do
  @moduledoc """
  少林山门 `guangchang1.c valid_leave/2` —— 完整 6 分支（不简化）。

  LPC 原文（`d/shaolin/guangchang1.c:130-190`）在玩家向北进寺时：

  1. 非 north → 交回基础房间判定；
  2. 少林派 + class != bonze → 「俗家弟子不得入寺修行」拒绝；
  3. 少林派 + class==bonze + guilty==0 + `K_record == WPK` →
     「师兄辛苦了，请进」放行；
  4. 少林派 + 上述不满足 → 若 guilty==0：按 `shen_record > shen` 置 guilty=1/2，
     再重置 `K_record=WPK`、`shen_record=shen`，**强制传送到戒律院 smdian**，
     播「请师兄去戒律院陈述此行过犯」并阻止原移动（返回 -1）；
  5. 非少林派 + 身上有英雄令（`yingxiong ling`）→ 「贵客驾到」放行；
  6. 非少林派 + shen>=0 → 女性「不接待女客」/ 其它「不接待俗人」拒绝；
     shen<0 → 戒刀威胁文案并阻止（LPC 此处**不调用攻击函数**，只 notify_fail）。

  ## 端口映射

  - 房间进程只读角色、算 effects；写 meta/传送由 `Kantele.Character.TrapEvent`
    在角色进程执行（与五行迷宫/八卦阵同一条已验证的链），避免跨进程改 meta。
  - `query("combat/K_record")` / `query("combat/WPK")` → 先读 `meta.env`
    （剃度在此写入 K_record/shen_record），再兼容 `meta.combat`（craft.ex 的 PKS/MKS/WPK）。
  - `query("guilty")` → `meta.guilty`；`query("shen")` → `meta.stats.shen`；
    `query("class")` → `meta.family.class`；`present("yingxiong ling", me)` →
    `RoomActions.Helpers.carries?/2`。
  """

  alias Kantele.Character.Family
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  @discipline_room "shaolin:smdian"
  @hero_item "yingxiong ling"

  @msg_lay "壮年僧人说道：对不起，俗家弟子不得入寺修行。\n"
  @msg_pass "壮年僧人侧身让开，说道：师兄辛苦了，请进。\n"
  @msg_discipline "壮年僧人沉下脸来，说道：戒律院主持玄痛大师请师兄去戒律院陈述此行过犯。\n"
  @msg_hero "壮年僧人合十为礼，侧身让开，说道：原来是贵客驾到，请进请进。\n"
  @msg_female "壮年僧人说道：这位女施主还是请回罢，本寺从不接待女客。\n"
  @msg_commoner "壮年僧人说道：这位施主请回罢，本寺不接待俗人。\n"
  @msg_evil "壮年僧人立时从身畔挚出一把雪亮的戒刀来，把明晃晃的刀尖对准你的\n" <>
              "胸口，横眉怒目地说道：“你等邪魔外道，还不给我滚开！以后再敢走\n" <>
              "近少林一步，我立时就斩断你们的狗腿！”\n\n"

  @doc """
  纯判定：`{:allow, effects}` 或 `{:block, message, effects}`。

  `room` 只用于保留扩展点（LPC 里会 check `exits/north`），当前实现按
  `dir == "north"` 判定；其它方向放行，交回基础房间出口逻辑。
  """
  def evaluate(mover, "north", _room) do
    meta = Map.get(mover, :meta) || %{}

    cond do
      shaolin?(meta) and class(meta) != "bonze" ->
        {:block, @msg_lay, []}

      shaolin?(meta) and clean?(meta) ->
        {:allow, [{:text, @msg_pass}]}

      shaolin?(meta) ->
        discipline(meta)

      hero_token?(mover) ->
        {:allow, [{:text, @msg_hero}]}

      shen(meta) >= 0 and gender(meta) == "女性" ->
        {:block, @msg_female, []}

      shen(meta) >= 0 ->
        {:block, @msg_commoner, []}

      true ->
        {:block, @msg_evil, []}
    end
  end

  def evaluate(_mover, _dir, _room), do: {:allow, []}

  # 戒律院分支：LPC 只在 guilty==0 时更新 guilty/记录；guilty>0 直接转送。
  defp discipline(meta) do
    guilty = Map.get(meta, :guilty, 0) || 0
    wpk = combat_value(meta, :WPK)
    shen = shen(meta)
    shen_record = combat_value(meta, :shen_record)

    effects =
      if guilty == 0 do
        new_guilty = if shen_record > shen, do: 1, else: 2

        [
          {:set_guilty, new_guilty},
          {:set_env, :K_record, wpk},
          {:set_env, :shen_record, shen}
        ]
      else
        []
      end

    {:block, @msg_discipline, effects ++ [{:force_move, @discipline_room}]}
  end

  defp shaolin?(meta) do
    case Map.get(meta, :family) do
      family when is_map(family) and map_size(family) > 0 ->
        case Family.name(family) do
          name when is_binary(name) -> name == "少林派"
          _ -> false
        end

      _ ->
        false
    end
  end

  defp class(meta) do
    case Map.get(meta, :family) do
      family when is_map(family) -> Map.get(family, :class)
      _ -> nil
    end
  end

  defp clean?(meta) do
    (Map.get(meta, :guilty, 0) || 0) == 0 and
      combat_value(meta, :K_record) == combat_value(meta, :WPK)
  end

  # LPC query("combat/K_record") 等：env 优先（剃度写入处），combat.temp 兜底。
  defp combat_value(meta, key) do
    env = Map.get(meta, :env) || %{}
    combat = Map.get(meta, :combat) || %{}
    temp = Map.get(combat, :temp) || %{}
    Map.get(env, key) || Map.get(env, to_string(key)) ||
      Map.get(temp, key) || Map.get(temp, to_string(key)) ||
      Map.get(combat, key) || Map.get(combat, to_string(key)) || 0
  end

  defp shen(meta), do: Map.get(Map.get(meta, :stats) || %{}, :shen, 0) || 0

  defp gender(meta) do
    env = Map.get(meta, :env) || %{}
    Map.get(env, :gender) || Map.get(env, "gender") || "男性"
  end

  defp hero_token?(mover) do
    RoomHelpers.carries?(mover, @hero_item)
  rescue
    _ -> false
  end
end
