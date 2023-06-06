defmodule Bling.PaddleTest.SubscriptionsTest do
  use Bling.PaddleTest.RepoCase
  alias Bling.Paddle.Subscriptions

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
end
