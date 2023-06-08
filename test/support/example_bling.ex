defmodule Bling.PaddleTest.ExampleBling do
  @behaviour Bling.Paddle

  @impl Bling.Paddle
  def paddle_customer_info(customer) do
    # valid map keys are `email`, `country`, and `postcode`
    case customer do
      %Bling.PaddleTest.User{} -> %{email: customer.email}
      _ -> %{}
    end
  end

  @impl Bling.Paddle
  def handle_paddle_webhook_event(_event) do
    :ok
  end
end
