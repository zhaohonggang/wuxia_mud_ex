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
end
