# 每次运行前清空数据库：上游 ExVenture 套件会写入固定用户名/邮箱，
# 上一次运行残留的行会触发 users_lower_username_index 唯一约束冲突。
tables =
  Ecto.Adapters.SQL.query!(
    ExVenture.Repo,
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('schema_migrations', 'schema_migrations_locks')"
  )
  |> Map.fetch!(:rows)
  |> List.flatten()

if tables != [] do
  Ecto.Adapters.SQL.query!(
    ExVenture.Repo,
    "TRUNCATE TABLE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE"
  )
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ExVenture.Repo, :manual)