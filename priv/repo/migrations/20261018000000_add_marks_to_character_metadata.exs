defmodule ExVenture.Repo.Migrations.AddMarksToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      # marks：剧情/任务持久标记（LPC `set("marks/<key>", 1)`）
      # 如 %{"qianlong" => 1}（乾隆跪拜已封赏），键为字符串、值为整数
      add(:marks, :map, default: %{})
    end
  end
end
