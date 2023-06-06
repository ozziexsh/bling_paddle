defmodule Bling.PaddleTest.User do
  use Ecto.Schema

  schema "users" do
    field(:email, :string)

    field(:trial_ends_at, :utc_datetime)

    has_many(:subscriptions, Bling.PaddleTest.Subscription,
      foreign_key: :customer_id,
      where: [customer_type: "user"],
      defaults: [customer_type: "user"]
    )

    has_many(:receipts, Bling.PaddleTest.Receipt,
      foreign_key: :customer_id,
      where: [customer_type: "user"],
      defaults: [customer_type: "user"]
    )

    timestamps()
  end

  defimpl Bling.Paddle.Entity do
    def repo(_), do: Bling.PaddleTest.Repo
    def bling(_), do: Bling.PaddleTest.ExampleBling
  end
end
