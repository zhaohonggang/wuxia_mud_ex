defmodule ExVenture.Repo.Migrations.AddGenderToCharacterMetadata do
  use Ecto.Migration

  @moduledoc """
  给 `character_metadata` 加 `gender` 列。

  背景：`data/world` 里有 11 条 `valid_leave` 条件读 `me->query("gender")`
  （如 `xiangyang:juyifemale` 的 `!= '女性'`），而 `query("...")` 走
  `meta.env`，之前没有任何地方写入 gender，于是这些条件恒为「男性 != '女性'」
  之类的假值 —— `LpcCondition.supported?/1` 只能整批跳过（见 @unsupported_fields）。

  放在 `character_metadata` 而不是 `characters`：性别是**玩法属性**，
  与同一张表里的 `family` 同类；且 `Records.apply_to_character/3` 已经在手上
  拿到 `metadata`，加这一列**不需要改动任何函数签名**。

  默认「男性」：`adm/daemons/updated.c` 就是 `me->set("gender", "男性")`，
  LPC 里绝大多数 NPC 也是男性，且 `logind.c` 是从 temp 拷过来（有默认值语义）。
  历史角色因此自动是男性 —— 下面 3 个门禁会随之「真的开始拦人」：
  `guiyun:duchuan` 往 west、`luoyang:yuchi` 往 up、`xiangyang:juyifemale` 往 east。
  """

  def change do
    alter table(:character_metadata) do
      add(:gender, :string, default: "男性", null: false)
    end
  end
end
