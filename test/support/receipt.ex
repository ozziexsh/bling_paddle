defmodule Bling.PaddleTest.Receipt do
  use Ecto.Schema

  schema "receipts" do
    field(:customer_id, :integer)
    field(:customer_type, :string)
    field(:paddle_subscription_id, :integer)
    field(:checkout_id, :string)
    field(:order_id, :string)
    field(:amount, :string)
    field(:tax, :string)
    field(:currency, :string)
    field(:quantity, :integer)
    field(:receipt_url, :string)
    field(:paid_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  defimpl Bling.Paddle.Entity do
    def repo(_entity), do: Bling.PaddleTest.Repo
    def bling(_), do: Bling.PaddleTest.ExampleBling
  end
end