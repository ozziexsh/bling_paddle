defmodule Bling.PaddleTest.ExampleBling do
  # this results in compilation errors "Bling.Entity is not a protocol"
  # help??
  #
  # use Bling.Paddle,
  #   repo: Bling.PaddleTest.Repo,
  #   customers: [user: Bling.PaddleTest.User],
  #   subscriptions: Bling.PaddleTest.Subscription,
  #   receipt: Bling.PaddleTest.Receipt

  # instead we have to manually implement the methods...
  def customers, do: [user: Bling.PaddleTest.User]
  def repo, do: Bling.PaddleTest.Repo
  def subscription, do: Bling.PaddleTest.Subscription
  def receipt, do: Bling.PaddleTest.Receipt

  def module_from_customer_type(type) do
    Enum.find_value(customers(), fn {name, mod} ->
      if to_string(name) == to_string(type), do: mod, else: nil
    end)
  end

  def customer_type_from_struct(customer) do
    Enum.find_value(customers(), fn {name, mod} ->
      if customer.__struct__ == mod, do: to_string(name), else: nil
    end)
  end
end
