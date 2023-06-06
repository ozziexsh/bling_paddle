defmodule Pmtr.Repo.Migrations.CreateSubscriptionsTable do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :customer_id, :bigserial, null: false
      add :customer_type, :string, null: false
      add :name, :string, null: false
      add :paddle_id, :integer, null: false
      add :paddle_status, :string, null: false
      add :paddle_plan, :integer, null: false
      add :quantity, :integer, null: false
      add :trial_ends_at, :utc_datetime, null: true
      add :paused_from, :utc_datetime, null: true
      add :ends_at, :utc_datetime, null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, :paddle_id)

    create table(:receipts) do
      add :customer_id, :bigserial, null: false
      add :customer_type, :string, null: false
      add :paddle_subscription_id, :bigserial, null: false
      add :checkout_id, :string, null: false
      add :order_id, :string, null: false
      add :amount, :string, null: false
      add :tax, :string, null: false
      add :currency, :string, null: false
      add :quantity, :integer, null: false
      add :receipt_url, :string, null: false
      add :paid_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:receipts, :paddle_subscription_id)
    create unique_index(:receipts, :order_id)
    create unique_index(:receipts, :receipt_url)
  end
end
