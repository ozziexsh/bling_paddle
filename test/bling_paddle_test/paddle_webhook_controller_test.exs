defmodule Bling.PaddleTest.PaddleWebhookControllerTest do
  use Bling.PaddleTest.RepoCase
  alias Bling.Paddle.Controllers.PaddleWebhookController
  alias Bling.PaddleTest.Repo
  alias Bling.PaddleTest.Subscription

  defp build_conn() do
    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.assign(:bling, Bling.PaddleTest.ExampleBling)
  end

  describe "payment succeeded" do
    test "it does nothing if receipt already exists" do
      customer = create_user()
      receipt = create_receipt(customer)

      PaddleWebhookController.webhook(build_conn(), %{
        "alert_name" => "payment_succeeded",
        "order_id" => receipt.order_id
      })

      assert Bling.PaddleTest.Repo.all(Bling.PaddleTest.Receipt) == [receipt]
    end

    test "it creates the receipt" do
      customer = create_user()

      params = %{
        "alert_name" => "payment_succeeded",
        "passthrough" =>
          Jason.encode!(%{
            customer_id: customer.id,
            customer_type: "user",
            subscription_name: "default"
          }),
        "checkout_id" => Ecto.UUID.generate(),
        "order_id" => Ecto.UUID.generate(),
        "sale_gross" => "10.00",
        "payment_tax" => "0.00",
        "currency" => "USD",
        "quantity" => "1",
        "receipt_url" => "http://localhost:4000/receipt",
        "event_time" => "2020-02-10 10:40:20"
      }

      PaddleWebhookController.webhook(build_conn(), params)

      receipts = Bling.PaddleTest.Repo.preload(customer, :receipts) |> Map.get(:receipts)

      assert receipts != []
      assert Enum.count(receipts) == 1

      [receipt] = receipts

      assert receipt.checkout_id == params["checkout_id"]
      assert receipt.order_id == params["order_id"]
      assert receipt.amount == params["sale_gross"]
      assert receipt.tax == params["payment_tax"]
      assert receipt.currency == params["currency"]
      assert receipt.quantity == 1
      assert receipt.receipt_url == params["receipt_url"]
      assert receipt.paid_at == ~U[2020-02-10 10:40:20Z]
    end
  end

  describe "subscription payment succeeded" do
    test "it does nothing if receipt exists already" do
      customer = create_user()
      receipt = create_receipt(customer)

      PaddleWebhookController.webhook(build_conn(), %{
        "alert_name" => "subscription_payment_succeeded",
        "order_id" => receipt.order_id
      })

      assert Bling.PaddleTest.Repo.all(Bling.PaddleTest.Receipt) == [receipt]
    end

    test "it creates the receipt" do
      customer = create_user()

      params = %{
        "alert_name" => "subscription_payment_succeeded",
        "passthrough" =>
          Jason.encode!(%{
            customer_id: customer.id,
            customer_type: "user",
            subscription_name: "default"
          }),
        "checkout_id" => Ecto.UUID.generate(),
        "order_id" => Ecto.UUID.generate(),
        "sale_gross" => "10.00",
        "payment_tax" => "0.00",
        "currency" => "USD",
        "quantity" => "1",
        "receipt_url" => "http://localhost:4000/receipt",
        "event_time" => "2020-02-10 10:40:20",
        "subscription_id" => "4567"
      }

      PaddleWebhookController.webhook(build_conn(), params)

      receipts = Bling.PaddleTest.Repo.preload(customer, :receipts) |> Map.get(:receipts)

      assert receipts != []
      assert Enum.count(receipts) == 1

      [receipt] = receipts

      assert receipt.checkout_id == params["checkout_id"]
      assert receipt.order_id == params["order_id"]
      assert receipt.amount == params["sale_gross"]
      assert receipt.tax == params["payment_tax"]
      assert receipt.currency == params["currency"]
      assert receipt.quantity == 1
      assert receipt.receipt_url == params["receipt_url"]
      assert receipt.paid_at == ~U[2020-02-10 10:40:20Z]
      assert receipt.paddle_subscription_id == 4567
    end
  end

  describe "subscription cancelled" do
    test "it does nothing if the subscription cant be found" do
      customer = create_user()
      create_subscription(customer)

      params = %{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => "1234"
      }

      PaddleWebhookController.webhook(build_conn(), params)

      cancelled = Repo.all(Subscription)

      assert not Enum.any?(cancelled, &(&1.paddle_status == "deleted"))
    end

    test "it cancels the subscription" do
      customer = create_user()
      sub = create_subscription(customer)

      params = %{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => to_string(sub.paddle_id),
        "cancellation_effective_date" => "2020-02-15",
        "status" => "deleted"
      }

      PaddleWebhookController.webhook(build_conn(), params)

      sub = Repo.reload(sub)

      assert sub.ends_at != nil
      assert sub.paused_from == nil
      assert sub.paddle_status == "deleted"
    end

    test "it sets the end date to the trial date if present" do
      customer = create_user()

      sub =
        create_subscription(customer, %{
          trial_ends_at: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)
        })

      params = %{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => to_string(sub.paddle_id),
        "cancellation_effective_date" => "2020-02-15",
        "status" => "deleted"
      }

      PaddleWebhookController.webhook(build_conn(), params)

      sub = Repo.reload(sub)

      assert sub.ends_at == sub.trial_ends_at
      assert sub.paused_from == nil
      assert sub.paddle_status == "deleted"
    end
  end

  describe "subscription updated" do
    test "it does nothing if it cant find the subscription" do
      customer = create_user()
      create_subscription(customer)

      params = %{
        "alert_name" => "subscription_updated",
        "subscription_id" => "12345"
      }

      conn = PaddleWebhookController.webhook(build_conn(), params)

      assert Phoenix.ConnTest.json_response(conn, 200)
    end

    test "it updates the subscription" do
      customer = create_user()

      sub = create_subscription(customer)

      params = %{
        "alert_name" => "subscription_updated",
        "subscription_id" => to_string(sub.paddle_id),
        "subscription_plan_id" => "4567",
        "status" => "paused",
        "paused_from" => "2020-02-15 10:20:15",
        "new_quantity" => "10"
      }

      PaddleWebhookController.webhook(build_conn(), params)

      sub = Repo.reload(sub)

      assert sub.paddle_status == "paused"
      assert sub.quantity == 10
      assert sub.paused_from == ~U[2020-02-15 10:20:15Z]
      assert sub.paddle_plan == 4567
    end
  end

  describe "subscription created" do
    test "trial" do
      customer = create_user()

      params = %{
        "alert_name" => "subscription_created",
        "subscription_id" => "1234",
        "subscription_plan_id" => "5678",
        "status" => "trialing",
        "next_bill_date" => "2020-10-15",
        "quantity" => "1",
        "passthrough" =>
          Jason.encode!(%{
            "subscription_name" => "default",
            "customer_id" => customer.id,
            "customer_type" => "user"
          })
      }

      PaddleWebhookController.webhook(build_conn(), params)

      sub = Repo.preload(customer, :subscriptions) |> Map.get(:subscriptions) |> List.first()

      assert sub.paddle_status == "trialing"
      assert sub.quantity == 1
      assert sub.paused_from == nil
      assert sub.paddle_id == 1234
      assert sub.paddle_plan == 5678
      assert sub.name == "default"
      assert sub.trial_ends_at == ~U[2020-10-15 00:00:00Z]
      assert sub.ends_at == nil
    end

    test "invalid passthrough continues" do
      params = %{
        "alert_name" => "subscription_created",
        "subscription_id" => "1234",
        "subscription_plan_id" => "5678",
        "status" => "trialing",
        "next_bill_date" => "2020-10-15",
        "quantity" => "1"
      }

      conn = PaddleWebhookController.webhook(build_conn(), params)

      assert Phoenix.ConnTest.json_response(conn, 200)
    end

    test "it creates the subscription" do
      customer = create_user()

      params = %{
        "alert_name" => "subscription_created",
        "subscription_id" => "1234",
        "subscription_plan_id" => "5678",
        "status" => "active",
        "quantity" => "1",
        "passthrough" =>
          Jason.encode!(%{
            "subscription_name" => "default",
            "customer_id" => customer.id,
            "customer_type" => "user"
          })
      }

      PaddleWebhookController.webhook(build_conn(), params)

      sub = Repo.preload(customer, :subscriptions) |> Map.get(:subscriptions) |> List.first()

      assert sub.paddle_status == "active"
      assert sub.quantity == 1
      assert sub.paused_from == nil
      assert sub.paddle_id == 1234
      assert sub.paddle_plan == 5678
      assert sub.name == "default"
      assert sub.trial_ends_at == nil
      assert sub.ends_at == nil
    end
  end
end
