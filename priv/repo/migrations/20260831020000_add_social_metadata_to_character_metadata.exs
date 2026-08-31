defmodule ExVenture.Repo.Migrations.AddSocialMetadataToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      # 社会系统持久化（P0，供 P2 结义/帮派/任务使用）
      # quest：任务进度快照（Kantele.Quest 状态序列化）
      add(:quest, :map, default: %{})
      # league：帮派信息（S2 league.c）：%{id, name, title, ...}
      add(:league, :map, default: %{})
      # brothers：结义列表（S1 brothers.c）：[%{id, name, ...}]
      add(:brothers, {:array, :map}, default: [])
    end
  end
end
