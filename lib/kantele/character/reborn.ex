defmodule Kantele.Character.Reborn do
  @moduledoc """
  转世重生（对应 LPC `updated.c` 的 `zhuan_player`，updated.c:447-745；触发前置见
  `d/death/npc/dizangwang.c:117-271` 的 `ask_zhuan` 四前置链）。

  ## 前置判定（LPC `ask_zhuan` + 计划 D2「四项齐备」）
  四项齐备方可进入六道轮回 → `zhuan_player`：
    ① 大宗师 = `combat_exp >= 800_000_000` 且 `meta.env[:ultrap]`（Ex 无 `ultrap`
       概念，按用户拍板以「exp 阈值 + 新标志」建模：exp 达标即视为大宗师，并镜像
       `meta.env[:ultrap]` 以便查询）。
       ⚠️ 注意：LPC 现行 `ask_zhuan` 中大宗师(`ultrap`)与 `animaout`(生死玄关) 两道
       校验**已被注释掉**(dizangwang.c:122-136)，仅 HellZhenPass/DiZangPass/SkyPass
       实际生效。本实现按**已批准计划 D2 四项齐备**保留大宗师，与玩家拍板一致。
    ② 十八层地狱 `meta.env[:HellZhenPass]`（dizangwang.c:138）
    ③ 十二重天 `meta.env[:SkyPass]`：在地藏王处交付「精元丹」后置位（accept_object，dizangwang.c:243-262）
    ④ 击败地藏王 `meta.env[:DiZangPass]`：赢下 `ask_zhuan` 的生死斗后置位（lost()，dizangwang.c:210）

  ## `zhuan_player` 步骤（updated.c 行号对应）
    - 458-459：性别「无性」→「男性」(meta.env[:gender])
    - 462-528：清记录（见 `clear_records`；LPC `delete("env")` 会清掉 gender/born，
       但 Ex 须**保留** env[:startroom]/[:setup_done]/[:gender]/[:born]/[:surname]/
       [:registered]/[:special_skills]/[:reborn]，故改为按键清除）
    - 514-515：set title「江湖游侠」(meta.title)、character「国士无双」(meta.character)
    - 530-565：数值清零；HP=max_qi=qi=100、max_jing=jing=100；mud_age=0、age=14
    - 567-577：删全部武功（stats.skills / stats.mapped 清空）
    - 579-602：reborn/count+1、reborn/point+1；随机 reborn.{str,con,int,dex}+1（各 50%）
    - 604-606：reincarnate()/reset_action() → Ex 落点回出生地（env[:startroom]）
    - 608-702：赠特技——1 普通技能(12 选1 排除已拥有) + 1 转世技能(8 选1，按
       int/dex 过滤，固定「神眼」shenyan) + int<16 兜底天道酬勤(tiandao)/否则天赋聪颖(clever)
       + 通慧神眼(shenyan)
       ⚠️ LPC 619 行 `delete("special_skill")` 被注释 → **与生俱来特技不清空**，转世叠加。

  ## Ex 落点
    - 特技授予形状同 `BornPlayer`：`attributes["special_skills"][id]=true` 并镜像
      `meta.env[:special_skills]`（重登经 Records.apply_to_character 回灌）。
    - 清记录覆盖 Ex 已有字段（family/league/brothers/spouse/quests/bag/marks/schedule
      等）；LPC 中 Ex 无对应字段者（couple/sex/animaout/breakup/…）为 no-op。
  """

  alias Kalevala.Character
  alias Kantele.Character.Records
  alias Kantele.Character.Stats

  @ultrap_combat_exp 800_000_000

  # 普通技能 12 选 1（updated.c:611-624）
  @ordinary_skills [
    "agile", "power", "ironskin", "hatred", "self", "divine",
    "cunning", "mystery", "health", "energy", "wrath", "might"
  ]

  # 转世技能 8 选 1（updated.c:643-652）；shenyan 固定赠送故先剔除
  @reborn_skills [
    "guibian", "guimai", "jinshen", "piyi", "qinzong", "wuxing", "shenyan", "tiandao"
  ]

  # env 中需在转世时按键清除的记录（保留 startroom/setup_done/gender/born/surname/
  # registered/special_skills/reborn 等注册相关键，见 clear_env/1）
  @clear_env_keys [
    :DiZangPass, :HellZhenPass, :SkyPass, :over_quest,
    :can_learn, :can_perform, :learned_literate, :skybook, :rumor, :map,
    :opinion, :opinions, :out_family, :quest, :quest_count, :luohan_winner,
    :story, :couple, :sex, :combat, :animaout, :breakup, :detach, :betrayer,
    :long, :born_family, :class, :static, :mark, :death, :mirror_task,
    :mirror_count, :can_learned, :gift
  ]

  # ---------------------------------------------------------------------------
  # 前置判定
  # ---------------------------------------------------------------------------

  @doc "大宗师判定（combat_exp≥800M + meta.env[:ultrap] 标志）。"
  def ultrap?(%Character{} = character) do
    character.meta.stats.combat_exp >= @ultrap_combat_exp
  end

  @doc """
  四前置是否齐备（HellZhenPass + DiZangPass + SkyPass + 大宗师/ultrap）。
  `meta.env[:ultrap]` 在 exp 达标时由调用方维护；此处直接以 exp 阈值判定，二者等价。
  """
  def prereqs_met?(%Character{} = character) do
    env = character.meta.env || %{}

    !!ultrap?(character) and
      Map.get(env, :HellZhenPass) == true and
      Map.get(env, :DiZangPass) == true and
      Map.get(env, :SkyPass) == true
  end

  @doc """
  转世触发（对应 LPC `d/death/npc/dizangwang.c` 的 `ask_zhuan` 四前置判定 + 执行）。

  四项齐备（见 `prereqs_met?`）则执行 `zhuan_player` 并落盘，返回 `{:ok, character}`；
  否则返回 `{:error, msg}`，`msg` 指明缺哪些前置（与 LPC 分步拒绝一致）。
  本函数是「地藏王问询转世」等价入口，亦供未来 `ask` 指令 / NPC 处理器调用。
  """
  def trigger(%Character{} = character) do
    case missing_prereqs(character) do
      [] ->
        character = zhuan_player(character)

        case Records.save(character) do
          :ok -> {:ok, character}
          :error -> {:error, "六道轮回动荡，转世未能落盘，请稍后再试。\n"}
        end

      missing ->
        {:error, refusal_message(missing)}
    end
  end

  @doc "返回未满足的前置项中文标签（空列表 = 齐备）。用于触发时分步拒绝。"
  def missing_prereqs(%Character{} = character) do
    env = character.meta.env || %{}

    []
    |> then(&if(ultrap?(character), do: &1, else: ["大宗师（修为未达 combat_exp≥800000000）" | &1]))
    |> then(&if(Map.get(env, :HellZhenPass) == true, do: &1, else: ["十八层地狱未通关（HellZhenPass）" | &1]))
    |> then(&if(Map.get(env, :DiZangPass) == true, do: &1, else: ["未击败地藏王（DiZangPass）" | &1]))
    |> then(&if(Map.get(env, :SkyPass) == true, do: &1, else: ["未献上精元丹·十二重天未过（SkyPass）" | &1]))
    |> Enum.reverse()
  end

  @doc "把缺项标签拼成地藏王的拒绝语（对应 LPC `ask_zhuan` 各步失败提示）。"
  def refusal_message(missing) when is_list(missing) do
    "地藏王冷然道：「你尚不具备转世之资——" <>
      Enum.join(missing, "；") <> "。且去补全因果，再来见我。」\n"
  end

  # ---------------------------------------------------------------------------
  # 转世主体
  # ---------------------------------------------------------------------------

  @doc """
  执行转世（updated.c:447-745）。返回更新后的 `Character`，不落盘（落盘由调用方负责）。

  `picker` 可注入（默认 `&Enum.random/1`）以便测试固定选取；reborn.{str,con,int,dex}
  的 50% 随机 +1 使用进程内随机（测试只断言增量 ∈ {0,1}）。
  """
  def zhuan_player(%Character{} = character, picker \\ &Enum.random/1) do
    character
    |> set_gender_if_wuxing()
    |> clear_records()
    |> reset_values()
    |> clear_skills()
    |> bump_reborn()
    |> random_reborn_bonus()
    |> grant_skills(picker)
    |> set_reborn_identity()
    |> place_at_rebirth()
  end

  # 458-459：性别「无性」→「男性」
  defp set_gender_if_wuxing(%Character{} = character) do
    env = character.meta.env || %{}

    if Map.get(env, :gender) == "无性" do
      put_env(character, :gender, "男性")
    else
      character
    end
  end

  # 462-528：清记录。保留注册相关 env 键（见 @clear_env_keys 注释）。
  defp clear_records(%Character{} = character) do
    character
    |> clear_meta_records()
    |> clear_env_records()
  end

  defp clear_meta_records(%Character{} = character) do
    meta = character.meta

    meta =
      meta
      |> Map.put(:family, nil)
      |> Map.put(:league, %{})
      |> Map.put(:brothers, [])
      |> Map.put(:spouse, %{})
      # quests 清空用 nil：Records.save 经 Quest.serialize 序列化，其不接受 [] 列表
      # （仅接受 nil / map），传 [] 会抛 FunctionClauseError 被 save 吞成 :error；
      # 正常存档路径本就以 nil 序列化（见 setup_persistence_test），故用 nil 表示已清。
      # bag 清空用 []（Backpack.serialize([]) 合法）。
      |> Map.put(:quests, nil)
      |> Map.put(:bag, [])
      |> Map.put(:marks, %{})
      |> Map.put(:schedule, nil)
      |> Map.put(:title, "江湖游侠")

    %{character | meta: meta}
  end

  defp clear_env_records(%Character{} = character) do
    env = character.meta.env || %{}
    env = Map.drop(env, @clear_env_keys)
    # 清 reborn/family 子键（updated.c:509 delete("reborn/family/mark")），保留 count/point
    # 统一补齐 count/point（缺省 0）再删 family：env[:reborn] 可能为 nil / %{} / 仅含
    # :family 的残缺 map（部分既有玩家数据），避免留下无 count/point 的 map 让后续
    # bump_reborn 步崩（%{reborn | count: ...} 要求键必存在）。首次转世前无记录 → 0/0，
    # 经 bump_reborn +1 后得 count=1/point=1，与 LPC reborn/count 起点一致。
    reborn = env[:reborn] || %{}
    reborn =
      reborn
      |> Map.put(:count, reborn[:count] || 0)
      |> Map.put(:point, reborn[:point] || 0)
      |> Map.delete(:family)

    env = Map.put(env, :reborn, reborn)
    # 重置年龄相关（updated.c:563-565）
    env = Map.put(env, :mud_age, 0)
    env = Map.put(env, :age, 14)
    %{character | meta: %{character.meta | env: env}}
  end

  # 530-565：数值清零 + 气血/精力重置
  defp reset_values(%Character{} = character) do
    stats =
      character.meta.stats
      |> Map.put(:combat_exp, 0)
      |> Map.put(:potential, 0)
      |> Map.put(:learned_points, 0)
      |> Map.put(:score, 0)
      |> Map.put(:weiwang, 0)
      |> Map.put(:gongxian, 0)
      |> Map.put(:shen, 0)
      |> Map.put(:tattoo, %{str: 0, int: 0, con: 0, dex: 0, per: 0})

    vitals = character.meta.vitals
    vitals =
      vitals
      |> Map.put(:max_neili, 0)
      |> Map.put(:neili, 0)
      |> Map.put(:base_neili, 0)
      |> Map.put(:max_jingli, 0)
      |> Map.put(:jingli, 0)
      |> Map.put(:max_qi, 100)
      |> Map.put(:qi, 100)
      |> Map.put(:base_qi, 100)
      |> Map.put(:max_jing, 100)
      |> Map.put(:jing, 100)
      |> Map.put(:base_jing, 100)

    character
    |> put_in([Access.key(:meta), Access.key(:stats)], stats)
    |> put_in([Access.key(:meta), Access.key(:vitals)], vitals)
  end

  # 567-577：删全部武功
  defp clear_skills(%Character{} = character) do
    stats = character.meta.stats
    stats = %{stats | skills: %{}, mapped: %{}}
    put_in(character, [Access.key(:meta), Access.key(:stats)], stats)
  end

  # 579-581：reborn/count+1、reborn/point+1
  defp bump_reborn(%Character{} = character) do
    env = character.meta.env || %{}
    # 用 Map.put 而非 %{reborn | count: ...}：env[:reborn] 可能为 nil / %{} / 仅含
    # :family 的残缺 map（部分既有玩家数据），`|` 更新要求键必存在会崩；Map.put 兼容。
    reborn = env[:reborn] || %{}
    reborn =
      reborn
      |> Map.put(:count, (reborn[:count] || 0) + 1)
      |> Map.put(:point, (reborn[:point] || 0) + 1)

    put_env(character, :reborn, reborn)
  end

  # 583-602：随机 reborn.{str,con,int,dex} +1（各 50%）
  defp random_reborn_bonus(%Character{} = character) do
    stats = character.meta.stats
    reborn = stats.reborn || %{str: 0, int: 0, con: 0, dex: 0}

    reborn = %{
      reborn
      | str: reborn.str + Enum.random([0, 1]),
        con: reborn.con + Enum.random([0, 1]),
        int: reborn.int + Enum.random([0, 1]),
        dex: reborn.dex + Enum.random([0, 1])
    }

    put_in(character, [Access.key(:meta), Access.key(:stats), Access.key(:reborn)], reborn)
  end

  # 608-702：赠特技
  defp grant_skills(%Character{} = character, picker) do
    owned = special_skill_ids(character)

    # 普通技能 12 选 1（排除已拥有）
    ordinary_pool = @ordinary_skills -- owned
    character = add_special(character, pick(picker, ordinary_pool))

    # 转世技能 8 选 1（剔除 shenyan + 已拥有 + 按 int/dex 过滤）
    int = Stats.int(character.meta.stats)
    dex = Stats.dex(character.meta.stats)
    owned2 = special_skill_ids(character)

    reborn_pool =
      (@reborn_skills -- ["shenyan"] -- owned2)
      |> reject_if(int < 16 or int > 25, "tiandao")
      |> reject_if(int < 35 or "tiandao" in owned2, "qinzong")
      |> reject_if(int < 22 or dex < 26, "guimai")

    character = add_special(character, pick(picker, reborn_pool))

    # int<16 且未得天道酬勤 → 赠 tiandao；否则未得天赋聪颖 → 赠 clever
    character =
      if Stats.int(character.meta.stats) < 16 and not has_special?(character, "tiandao") do
        add_special(character, "tiandao")
      else
        if not has_special?(character, "clever") do
          add_special(character, "clever")
        else
          character
        end
      end

    # 通慧神眼（shenyan）固定赠送（若尚未拥有）
    if not has_special?(character, "shenyan") do
      add_special(character, "shenyan")
    else
      character
    end
  end

  # 514-515：character=国士无双、title=江湖游侠（title 已在 clear_meta_records 置）
  defp set_reborn_identity(%Character{} = character) do
    meta = Map.put(character.meta, :character, "国士无双")
    %{character | meta: meta}
  end

  # 604-606：reincarnate()/reset_action() → 落点回出生地
  defp place_at_rebirth(%Character{} = character) do
    startroom = Map.get(character.meta.env || %{}, :startroom) || Kantele.World.born_room_id()
    %{character | room_id: startroom}
  end

  # ---------------------------------------------------------------------------
  # 工具
  # ---------------------------------------------------------------------------

  defp pick(_picker, []), do: nil
  defp pick(picker, list) when is_list(list), do: picker.(list)

  defp reject_if(list, false, _id), do: list
  defp reject_if(list, true, id), do: List.delete(list, id)

  defp special_skill_ids(%Character{} = character) do
    character.attributes
    |> Map.get("special_skills", %{})
    |> Map.keys()
  end

  defp has_special?(%Character{} = character, id) do
    character.attributes
    |> Map.get("special_skills", %{})
    |> Map.has_key?(id)
  end

  defp add_special(%Character{} = character, nil), do: character

  defp add_special(%Character{} = character, id) when is_binary(id) do
    attrs = character.attributes || %{}
    ss = Map.get(attrs, "special_skills", %{}) |> Map.put(id, true)
    character = %{character | attributes: Map.put(attrs, "special_skills", ss)}

    # env 镜像 == attributes 中全部特技键（含「与生俱来」等历史特技），
    # 直接以 attributes 为准重建，避免增量合并时漏掉刚授予的技能
    env = (character.meta.env || %{}) |> Map.put(:special_skills, Map.keys(ss))
    %{character | meta: %{character.meta | env: env}}
  end

  # 通用：把 env 键写入（保留其余键）
  defp put_env(%Character{} = character, key, value) when key != :_ do
    env = (character.meta.env || %{}) |> Map.put(key, value)
    %{character | meta: %{character.meta | env: env}}
  end
end
