defmodule Bling.PaddleTest.SubscriptionsTest do
  use Bling.PaddleTest.RepoCase
  alias Bling.Paddle.Subscriptions

  def mock_api(opts \\ []) do
    result = opts[:response] || nil
    amount = opts[:amount] || 1

    Mox.defmock(Bling.PaddleTest.MockHTTP, for: Bling.Paddle.Http)
    Application.put_env(:bling_paddle, :http_lib, Bling.PaddleTest.MockHTTP)

    Bling.PaddleTest.MockHTTP
    |> Mox.expect(:post, amount, fn _, _, _ ->
      {:ok, %HTTPoison.Response{body: Jason.encode!(%{response: result})}}
    end)
  end

  describe "status checks" do
    test "active sub" do
      customer = create_user()
      subscription = create_subscription(customer)

      assert Subscriptions.valid?(subscription)
      assert Subscriptions.active?(subscription)
      assert not Subscriptions.past_due?(subscription)
      assert Subscriptions.recurring?(subscription)
      assert not Subscriptions.paused?(subscription)
      assert not Subscriptions.paused_grace_period?(subscription)
      assert not Subscriptions.cancelled?(subscription)
      assert not Subscriptions.ended?(subscription)
      assert not Subscriptions.trial?(subscription)
      assert not Subscriptions.expired_trial?(subscription)
      assert not Subscriptions.grace_period?(subscription)
    end

    test "trialing" do
      customer = create_user()

      trial =
        create_subscription(customer, %{
          paddle_status: "trialing",
          trial_ends_at: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)
        })

      assert Subscriptions.valid?(trial)
      assert Subscriptions.active?(trial)
      assert not Subscriptions.past_due?(trial)
      assert not Subscriptions.recurring?(trial)
      assert not Subscriptions.paused?(trial)
      assert not Subscriptions.paused_grace_period?(trial)
      assert not Subscriptions.cancelled?(trial)
      assert not Subscriptions.ended?(trial)
      assert Subscriptions.trial?(trial)
      assert not Subscriptions.expired_trial?(trial)
      assert not Subscriptions.grace_period?(trial)
    end

    test "expired trial" do
      customer = create_user()

      expired_trial =
        create_subscription(customer, %{
          paddle_status: "trialing",
          trial_ends_at:
            DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second),
          ends_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)
        })

      assert not Subscriptions.valid?(expired_trial)
      assert not Subscriptions.active?(expired_trial)
      assert not Subscriptions.past_due?(expired_trial)
      assert not Subscriptions.recurring?(expired_trial)
      assert not Subscriptions.paused?(expired_trial)
      assert not Subscriptions.paused_grace_period?(expired_trial)
      assert Subscriptions.cancelled?(expired_trial)
      assert Subscriptions.ended?(expired_trial)
      assert not Subscriptions.trial?(expired_trial)
      assert Subscriptions.expired_trial?(expired_trial)
      assert not Subscriptions.grace_period?(expired_trial)
    end

    test "ended" do
      customer = create_user()

      ended =
        create_subscription(customer, %{
          paddle_status: "deleted",
          ends_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)
        })

      assert not Subscriptions.valid?(ended)
      assert not Subscriptions.active?(ended)
      assert not Subscriptions.past_due?(ended)
      assert not Subscriptions.recurring?(ended)
      assert not Subscriptions.paused?(ended)
      assert not Subscriptions.paused_grace_period?(ended)
      assert Subscriptions.cancelled?(ended)
      assert Subscriptions.ended?(ended)
      assert not Subscriptions.trial?(ended)
      assert not Subscriptions.expired_trial?(ended)
      assert not Subscriptions.grace_period?(ended)
    end

    test "ending soon" do
      customer = create_user()

      ending_soon =
        create_subscription(customer, %{
          paddle_status: "deleted",
          ends_at: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)
        })

      assert Subscriptions.valid?(ending_soon)
      assert Subscriptions.active?(ending_soon)
      assert not Subscriptions.past_due?(ending_soon)
      assert not Subscriptions.recurring?(ending_soon)
      assert not Subscriptions.paused?(ending_soon)
      assert not Subscriptions.paused_grace_period?(ending_soon)
      assert Subscriptions.cancelled?(ending_soon)
      assert not Subscriptions.ended?(ending_soon)
      assert not Subscriptions.trial?(ending_soon)
      assert not Subscriptions.expired_trial?(ending_soon)
      assert Subscriptions.grace_period?(ending_soon)
    end

    test "paused" do
      customer = create_user()

      subscription =
        create_subscription(customer, %{
          paddle_status: "paused",
          paused_from: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
        })

      assert not Subscriptions.valid?(subscription)
      assert not Subscriptions.active?(subscription)
      assert not Subscriptions.past_due?(subscription)
      assert not Subscriptions.recurring?(subscription)
      assert Subscriptions.paused?(subscription)
      assert not Subscriptions.paused_grace_period?(subscription)
      assert not Subscriptions.cancelled?(subscription)
      assert not Subscriptions.ended?(subscription)
      assert not Subscriptions.trial?(subscription)
      assert not Subscriptions.expired_trial?(subscription)
      assert not Subscriptions.grace_period?(subscription)
    end

    test "paused grace period" do
      customer = create_user()

      subscription =
        create_subscription(customer, %{
          paused_from: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
        })

      assert Subscriptions.valid?(subscription)
      assert Subscriptions.active?(subscription)
      assert not Subscriptions.past_due?(subscription)
      assert not Subscriptions.recurring?(subscription)
      assert not Subscriptions.paused?(subscription)
      assert Subscriptions.paused_grace_period?(subscription)
      assert not Subscriptions.cancelled?(subscription)
      assert not Subscriptions.ended?(subscription)
      assert not Subscriptions.trial?(subscription)
      assert not Subscriptions.expired_trial?(subscription)
      assert not Subscriptions.grace_period?(subscription)
    end
  end

  describe "swap" do
    test "changes the plan" do
      customer = create_user()
      sub = create_subscription(customer)

      mock_api()

      Subscriptions.swap(sub, plan_id: 789)

      sub = Repo.reload(sub)

      assert sub.paddle_plan == 789
    end
  end

  describe "quantity" do
    test "incrementing" do
      customer = create_user()
      sub = create_subscription(customer)

      mock_api(amount: 2)

      Subscriptions.increment(sub)

      sub = Repo.reload(sub)

      assert sub.quantity == 2

      Subscriptions.increment(sub, quantity: 2)

      sub = Repo.reload(sub)

      assert sub.quantity == 4
    end

    test "decrementing" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          quantity: 5
        })

      mock_api(amount: 2)

      Subscriptions.decrement(sub)

      sub = Repo.reload(sub)

      assert sub.quantity == 4

      Subscriptions.decrement(sub, quantity: 2)

      sub = Repo.reload(sub)

      assert sub.quantity == 2
    end

    test "setting explicit quantity" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          quantity: 5
        })

      mock_api(amount: 2)

      Subscriptions.update_quantity(sub)

      sub = Repo.reload(sub)

      assert sub.quantity == 1

      Subscriptions.update_quantity(sub, quantity: 4)

      sub = Repo.reload(sub)

      assert sub.quantity == 4
    end
  end

  test "it guards against updates" do
    customer = create_user()

    sub =
      create_subscription(customer, %{
        trial_ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
      })

    assert_raise RuntimeError, "Cannot update while on trial.", fn ->
      Subscriptions.swap(sub, plan_id: 789)
    end

    sub =
      create_subscription(customer, %{
        paddle_status: "paused",
        paused_from: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      })

    assert_raise RuntimeError, "Cannot update paused subscriptions.", fn ->
      Subscriptions.swap(sub, plan_id: 789)
    end

    sub =
      create_subscription(customer, %{
        paddle_status: "deleted",
        ends_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      })

    assert_raise RuntimeError, "Cannot update cancelled subscriptions", fn ->
      Subscriptions.swap(sub, plan_id: 789)
    end

    sub =
      create_subscription(customer, %{
        paddle_status: "past_due"
      })

    assert_raise RuntimeError, "Cannot update past due subscriptions.", fn ->
      Subscriptions.swap(sub, plan_id: 789)
    end
  end

  describe "cancel subscription" do
    test "if paused_from is in the future, sets ends_at to paused_from" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          paddle_status: "paused",
          paused_from: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
        })

      mock_api(amount: 1)

      Subscriptions.cancel(sub)

      sub = Repo.reload(sub)

      assert sub.ends_at == sub.paused_from
    end

    test "if paused_from is past, sets ends_at to now" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          paddle_status: "paused",
          paused_from: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
        })

      mock_api(amount: 1)

      Subscriptions.cancel(sub)

      sub = Repo.reload(sub)

      assert DateTime.to_date(sub.ends_at) == Date.utc_today()
    end

    test "if on an active trial, sets ends_at to trial end date" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          paddle_status: "trialing",
          trial_ends_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
        })

      mock_api(amount: 1)

      Subscriptions.cancel(sub)

      sub = Repo.reload(sub)

      assert sub.ends_at == sub.trial_ends_at
    end

    test "it sets the ends_at to the period end" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          paddle_status: "trialing",
          trial_ends_at:
            DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
        })

      mock_api(
        amount: 4,
        response: [
          %{
            next_payment: %{
              date: "2070-10-15 10:15:20"
            }
          }
        ]
      )

      Subscriptions.cancel(sub)

      sub = Repo.reload(sub)

      assert sub.ends_at == ~U[2070-10-15 10:15:20Z]

      sub = create_subscription(customer)

      Subscriptions.cancel(sub)

      sub = Repo.reload(sub)

      assert sub.ends_at == ~U[2070-10-15 10:15:20Z]
    end

    test "cancel now" do
      customer = create_user()
      sub = create_subscription(customer)

      mock_api(amount: 1)

      Subscriptions.cancel_now(sub)

      sub = Repo.reload(sub)

      assert DateTime.to_date(sub.ends_at) == Date.utc_today()
    end

    test "cancel at" do
      customer = create_user()
      sub = create_subscription(customer)

      mock_api(amount: 1)

      ends_at = DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)

      Subscriptions.cancel_at(sub, ends_at)

      sub = Repo.reload(sub)

      assert sub.ends_at == ends_at
    end
  end

  describe "pause" do
    test "it pauses the subscription" do
      customer = create_user()
      sub = create_subscription(customer)

      mock_api(
        amount: 2,
        response: [
          %{state: "paused", paused_from: "2025-02-10 10:12:15"}
        ]
      )

      Subscriptions.pause(sub)

      sub = Repo.reload(sub)

      assert sub.paddle_status == "paused"
      assert sub.paused_from == ~U[2025-02-10 10:12:15Z]
    end

    test "it unpauses the subscription" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          paddle_status: "paused",
          paused_from: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
        })

      mock_api(amount: 1)

      Subscriptions.unpause(sub)

      sub = Repo.reload(sub)

      assert sub.paddle_status == "active"
      assert sub.paused_from == nil
    end
  end
end
