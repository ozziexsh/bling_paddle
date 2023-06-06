defmodule Bling.PaddleTest.CustomersTest do
  use Bling.PaddleTest.RepoCase
  alias Bling.Paddle.Customers

  test "it can create checkout urls" do
    customer = create_user()

    id = Application.get_env(:bling_paddle, :paddle_test_product)

    url = Customers.create_subscription(customer, product_id: id)

    assert String.contains?(url, "/checkout/custom/")
  end

  test "it can create pay urls" do
    customer = create_user()

    id = Application.get_env(:bling_paddle, :paddle_test_product)

    url = Customers.generate_pay_link(customer, product_id: id)

    assert String.contains?(url, "/checkout/custom/")
  end

  test "generic trials" do
    customer = create_user()
    assert not Customers.trial?(customer)
    assert not Customers.generic_trial?(customer)

    trial =
      create_user(%{
        trial_ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
      })

    assert Customers.generic_trial?(trial)
    assert Customers.trial?(trial)

    expired_trial =
      create_user(%{
        trial_ends_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      })

    assert not Customers.generic_trial?(expired_trial)
    assert not Customers.trial?(expired_trial)
  end

  test "subscription trials" do
    customer = create_user()
    assert not Customers.trial?(customer)
    assert not Customers.generic_trial?(customer)

    create_subscription(customer)
    assert not Customers.trial?(customer)
    assert not Customers.generic_trial?(customer)

    trial_customer = create_user()

    create_subscription(trial_customer, %{
      trial_ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
    })

    assert Customers.trial?(trial_customer)
    assert not Customers.generic_trial?(trial_customer)

    expired_customer = create_user()

    create_subscription(expired_customer, %{
      trial_ends_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
    })

    assert not Customers.trial?(expired_customer)
    assert not Customers.generic_trial?(expired_customer)
  end

  test "fetching subscriptions" do
    customer = create_user()

    assert Customers.subscription(customer) == nil
    assert Customers.subscriptions(customer) == []
    assert not Customers.subscribed?(customer)

    sub = create_subscription(customer)

    assert Customers.subscription(customer) == sub
    assert Customers.subscription(customer, name: "default") == sub
    assert Customers.subscriptions(customer) == [sub]
    assert Customers.subscribed?(customer)

    second = create_subscription(customer, %{name: "second"})
    assert Customers.subscription(customer) == sub
    assert Customers.subscription(customer, name: "default") == sub
    assert Customers.subscription(customer, name: "second") == second
    assert Customers.subscribed?(customer)
    assert Customers.subscribed?(customer, name: "default")
    assert Customers.subscribed?(customer, name: "second")
  end
end
