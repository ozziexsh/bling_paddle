defmodule Demo.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :trial_ends_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
