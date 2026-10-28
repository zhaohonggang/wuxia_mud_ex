defmodule Kantele.World.Forging do
  @moduledoc """
  锻造会话状态（取代 LPC 跨进程 `set_temp("item/...")`）。

  LPC 在莫邪、玩家、干将三个进程各持一份 `item/*` 临时变量。Kalevala 跨进程读写对方
  `meta.temp` 代价高，故用一张 ETS 表集中存会话，key = `character.id`（玩家）。

  会话结构（见 `forging_subsystem_plan.zh-CN.md` §1.1）：
    %{
      status,            # look_working | waiting | accept | item_gived | answer_type | inputing
      value,             # 估价（显示用「两黄金」数值，= power_point*2+20）
      material_item_id,  # 材料 item_id（取 can_make/not_make/power_point）
      material_instance_id, money_instance_id,  # 实物实例，物理上在莫邪背包
      owner_id, owner_name,
      types,             # 允许类型列表（来自 can_make/not_make 的中文 ctype）
      ctype, stype, unit, point, prop, wscale,  # 选型后填充（S1c/S3 用）
      can_help,          # 是否可「注内力」（S2 用）
      name, sid, long, wield_msg, unwield_msg,   # 定制输入（S3 用）
      item_make          # 生成物标记（S3/S4 用）
    }
  """

  @table :forging_sessions

  @doc "确保 ETS 表存在（幂等）。"
  def ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end

    :ok
  end

  def get(char_id) do
    ensure_table()

    case :ets.lookup(@table, char_id) do
      [{^char_id, session}] -> session
      [] -> nil
    end
  end

  def put(char_id, session) when is_map(session) do
    ensure_table()
    :ets.insert(@table, {char_id, session})
    session
  end

  def update(char_id, fun) when is_function(fun, 1) do
    ensure_table()
    current = get(char_id) || %{}
    put(char_id, fun.(current))
  end

  def delete(char_id) do
    ensure_table()
    :ets.delete(@table, char_id)
  end

  # ---- 类型表（LPC moye.c L22–92，§2 唯一真源） ----
  # key = 中文 ctype（玩家 `answer <类型>` 输入的即是此 key）
  # value 字段：type/stype/unit/weight(point 分量)/point(伤害系数)/prop
  @type_table %{
    "刀" => %{type: "weapon", stype: "blade", unit: "把", weight: 150, point: 100, prop: 0},
    "剑" => %{type: "weapon", stype: "sword", unit: "柄", weight: 150, point: 100, prop: 0},
    "棍" => %{type: "weapon", stype: "club", unit: "根", weight: 150, point: 100, prop: 0},
    "杖" => %{type: "weapon", stype: "staff", unit: "根", weight: 150, point: 100, prop: 0},
    "锤" => %{type: "weapon", stype: "hammer", unit: "把", weight: 350, point: 100, prop: 0},
    "斧" => %{type: "weapon", stype: "axe", unit: "把", weight: 220, point: 100, prop: 0},
    "鞭" => %{type: "weapon", stype: "whip", unit: "根", weight: 150, point: 100, prop: 0},
    "短兵" => %{type: "weapon", stype: "dagger", unit: "支", weight: 30, point: 100, prop: 0},
    "护甲" => %{type: "armor", stype: "armor", unit: "张", weight: 150, point: 80, prop: "armor_prop"},
    "战衣" => %{type: "armor", stype: "cloth", unit: "件", weight: 200, point: 100, prop: 0},
    "靴子" => %{type: "armor", stype: "boots", unit: "双", weight: 60, point: 40, prop: "armor_prop"},
    "头盔" => %{type: "armor", stype: "head", unit: "顶", weight: 75, point: 50, prop: 0},
    "腰带" => %{type: "armor", stype: "waist", unit: "条", weight: 80, point: 40, prop: 0},
    "护腕" => %{type: "armor", stype: "wrists", unit: "对", weight: 50, point: 25, prop: "armor_prop"},
    "箫" => %{type: "weapon", stype: "xsword", unit: "支", weight: 30, point: 100, prop: 0},
    "铁掌" => %{type: "armor", stype: "hands", unit: "双", weight: 45, point: 100, prop: "armor_prop"},
    "指套" => %{type: "armor", stype: "hands", unit: "套", weight: 35, point: 100, prop: "armor_prop"}
  }

  @doc "类型表所有中文 ctype 键。"
  def all_types, do: Map.keys(@type_table)

  @doc """
  依 `can_make`/`not_make` 计算允许锻造的类型列表（中文 ctype）。

  - `can_make == "all"` → 全部类型
  - `can_make` 为列表/字符串 → 取对应子集
  - `not_make` 为列表/字符串 → 从结果中剔除
  """
  def types_for(can_make, not_make) do
    base =
      case can_make do
        "all" -> all_types()
        list when is_list(list) -> list
        str when is_binary(str) -> [str]
        _ -> []
      end

    to_remove =
      case not_make do
        list when is_list(list) -> MapSet.new(list)
        str when is_binary(str) -> MapSet.new([str])
        _ -> MapSet.new()
      end

    Enum.reject(base, fn t -> MapSet.member?(to_remove, t) end)
  end

  @doc "取某 ctype 的类型表条目（S3 生成物品时用）。"
  def type_entry(ctype), do: Map.get(@type_table, ctype)

  # ---- 生成物攻防属性（S3 finish，对应 moye.c L22-92 的 ITEM_PROP 列） ----
  #
  # moye.c 的类型表第 6 项（`#define ITEM_PROP 5`）是「特殊变量」：要么是 0，
  # 要么是一张 `armor_prop` mapping。ganjiang.c 落盘时（L1070-1073）：
  #
  #     if (!info["prop"])  set("armor_prop/armor", apply_armor());
  #     else                prop_segment(info["prop"], "");   // 逐键展开
  #
  # 所以「无 prop」的类型只拿一条 `armor_prop/armor`，「有 prop」的类型拿整张表
  # （表里自己带 `armor` 键）。两边的 `apply_armor()` / `apply_damage()` 都是
  # **在生成文件 create() 时求值**的，参数只取决于 point 与 owner，故这里直接算成
  # 整数（`Craft.apply_armor/2` 恒等于 point，`Craft.apply_damage/3` 在 owner 为空
  # 时为 point/2）。
  #
  # 注意 `armor_prop/armor` 在本仓走 `%Meta{armor: ...}`（快照 `:armor` →
  # `applies[:armor]`），其余键走 `%Meta{armor_prop: ...}`（快照 `:prop` 并入
  # `applies`），两者最终落点一致，都是 LPC 的 `query_temp("apply/...")`。

  # 护腕的 15 个技能键（moye.c L51-66；源文件里 `"whip"` 写了两遍，mapping 字面量
  # 后写覆盖前写，去重后仍是这 15 个）。
  @wrist_skills ~w(sword staff blade club hammer whip dagger stick unarmed claw cuff hand strike finger parry)a

  @doc """
  防具的有效防御值（LPC `apply_armor()` 的求值结果）。

  - 铁掌 / 指套：LPC 的 prop 表把 `armor` 写死成 `"10"`，不吃 point
  - 其余（护甲/战衣/靴子/头盔/腰带/护腕）：`apply_armor()` = point
  """
  def armor_value("铁掌", _point), do: 10
  def armor_value("指套", _point), do: 10
  def armor_value(_ctype, point) when is_integer(point), do: point
  def armor_value(_ctype, _point), do: 0

  @doc """
  防具的额外 `armor_prop` 表（不含 `armor` 键，那个走 `armor_value/2`）。

  无 prop 的类型（战衣/头盔/腰带）返回 nil —— LPC 只给它们写一条
  `armor_prop/armor`。
  """
  def armor_prop("护甲", point) when is_integer(point), do: %{parry: div(point, 15) + 1}
  def armor_prop("靴子", point) when is_integer(point), do: %{dodge: div(point, 10) + 1}

  def armor_prop("护腕", point) when is_integer(point),
    do: Map.new(@wrist_skills, fn skill -> {skill, div(point, 6) + 1} end)

  def armor_prop("铁掌", point) when is_integer(point),
    do: %{cuff: 10, strike: 10, unarmed: 10, unarmed_damage: unarmed_damage(point)}

  def armor_prop("指套", point) when is_integer(point),
    do: %{claw: 10, finger: 10, hand: 10, unarmed_damage: unarmed_damage(point)}

  def armor_prop(_ctype, _point), do: nil

  @doc """
  武器的伤害值（LPC `init_<stype>(apply_damage())`）。

  `apply_damage()` 取 `weapon_level()`，而新打造的物品 `owner` 还是空表 →
  等级 0 → 分档 1 → `d = 1/81 * point/2` 截断为 0，只剩 `point / 2`。
  本仓没有移植「击杀累积 owner → 武器升级」这条链（`Meta.owner` 存的是主人
  姓名而非 LPC 的 `id => exp` 映射），故生成时按 owner 为空求值，武器不会随
  使用变强。
  """
  def weapon_damage(_ctype, point) when is_integer(point),
    do: Kantele.Item.Craft.apply_damage(0, point, 0)

  def weapon_damage(_ctype, _point), do: 0

  # LPC `apply_damage()`，铁掌/指套的 `armor_prop/unarmed_damage` 用它
  defp unarmed_damage(point), do: weapon_damage("铁掌", point)

  # ---- 乾坤袋（S4 边界分支，对应 LPC moye.c do_show L213 / accept_object L328-366 / L433） ----

  # 乾坤石与如意乾坤袋的 item_id。LPC 用 `query("id") == "qiankun stone"` 判定；
  # 本仓物品 id 带 zone 前缀，故用固定 id 常量，避免按名字匹配。
  @qiankun_stone_id "signature:qiankun_stone"
  @qiankun_bag_id "signature:qiankun_bag"

  @doc "乾坤石 item_id"
  def qiankun_stone_id, do: @qiankun_stone_id

  @doc "如意乾坤袋 item_id"
  def qiankun_bag_id, do: @qiankun_bag_id

  @doc "是否乾坤石（LPC `ob->query(\"id\") == \"qiankun stone\"`）"
  def qiankun_stone?(%{id: id}), do: id == @qiankun_stone_id
  def qiankun_stone?(_), do: false

  # ---- 锻造两位 NPC 的完整角色 id ----
  #
  # LPC 用 `present("ganjiang", environment())` 按**别名**找对象；本仓房间角色列表
  # 里 `:id` 是带 zone 前缀的完整 id（`signature:ganjiang`），不是裸名。
  # 早先 `ForgingAnswer.find_ganjiang/2` 拿裸 `"ganjiang"` 比对，永远匹配不上，
  # 于是生产路径每次都走「我夫君呢？」退款分支 —— 整条锻造链根本到不了干将。
  @moye_id "signature:moye"
  @ganjiang_id "signature:ganjiang"

  @doc "莫邪完整角色 id"
  def moye_id, do: @moye_id

  @doc "干将完整角色 id"
  def ganjiang_id, do: @ganjiang_id

  @doc """
  玩家当前背包扩展格总数（LPC `me->query("storage_bag")`）。

  本仓没有角色级 `storage_bag` 属性，扩展格挂在**背包物品**上：
  实例 meta `"storage_bag"`（升级后的绝对值）优先，否则退回定义 meta 的
  `storage_bag`。总容量 = 基础格（按 combat_exp）+ 这里算出的扩展之和
  （见 `backpack_command.ex` 的 `bag_state/1`）。
  """
  def bag_extra(%{inventory: inventory}) when is_list(inventory) do
    Enum.reduce(inventory, 0, fn instance, acc -> acc + instance_extra(instance) end)
  end

  def bag_extra(_), do: 0

  @doc """
  取单件背包实例的扩展格数：实例 meta 覆盖定义 meta。

  **必须写实例**：`%Kalevala.World.Item{}` 是全局共享只读定义，直接改定义会把
  一个玩家的升级摊到所有玩家身上。
  """
  def instance_extra(%{item_id: item_id} = instance) do
    override = Map.get(instance.meta || %{}, "storage_bag")

    cond do
      is_integer(override) ->
        max(override, 0)

      true ->
        case Kantele.World.Items.get(item_id) do
          {:ok, %{meta: %{storage_bag: n}}} when is_integer(n) and n > 0 -> n
          _ -> 0
        end
    end
  end

  @doc """
  给背包 +delta 格（升级），只改**实例** meta，不动全局定义。

  返回 `{新 character, 升级后的扩展格总数}`；没有背包容器时原样返回。
  """
  def upgrade_bag(%{inventory: inventory} = character, delta) when delta > 0 do
    case Enum.find_index(inventory, &(instance_extra(&1) > 0)) do
      nil ->
        {character, bag_extra(character)}

      idx ->
        instance = Enum.at(inventory, idx)
        new_meta = Map.put(instance.meta || %{}, "storage_bag", instance_extra(instance) + delta)
        updated = %{instance | meta: new_meta}
        character = %{character | inventory: List.replace_at(inventory, idx, updated)}
        {character, bag_extra(character)}
    end
  end
end
