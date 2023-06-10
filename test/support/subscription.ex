defmodule Bling.PaddleTest.Subscription do
  use Ecto.Schema

  schema "subscriptions" do
    field(:customer_id, :integer)
    field(:customer_type, :string)
    field(:name, :string)
    field(:paddle_id, :integer)
    field(:paddle_status, :string)
    field(:paddle_plan, :integer)
    field(:quantity, :integer)
    field(:trial_ends_at, :utc_datetime)
    field(:paused_from, :utc_datetime)
    field(:ends_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end
end
