defmodule Bling.Paddle.Controllers.PaddleWebhookController do
  alias Bling.Paddle.Subscriptions
  use Phoenix.Controller

  def webhook(conn, params) do
    if verify_signature(params) do
      bling = Bling.Paddle.bling()

      handle(params)

      Bling.Paddle.Util.maybe_call({bling, :handle_paddle_webhook_event, [params]})

      conn |> json(%{ok: true})
    else
      conn |> json(%{ok: false, message: "invalid signature"})
    end
  end

  def handle(%{"alert_name" => "payment_succeeded"} = payload) do
    with nil <- receipt_exists(payload["order_id"]),
         {:ok, passthrough} <- verify_passthrough(payload) do
      {:ok, paid_at, _} = "#{payload["event_time"]}Z" |> DateTime.from_iso8601()

      Bling.Paddle.receipt()
      |> struct()
      |> Ecto.Changeset.change(%{
        customer_id: passthrough["customer_id"],
        customer_type: passthrough["customer_type"],
        checkout_id: payload["checkout_id"],
        order_id: payload["order_id"],
        amount: payload["sale_gross"],
        tax: payload["payment_tax"],
        currency: payload["currency"],
        quantity: str_int(payload["quantity"]),
        receipt_url: payload["receipt_url"],
        paid_at: paid_at |> DateTime.truncate(:second)
      })
      |> Bling.Paddle.repo().insert!()
    else
      _ -> nil
    end
  end

  def handle(%{"alert_name" => "subscription_payment_succeeded"} = payload) do
    with nil <- receipt_exists(payload["order_id"]),
         {:ok, passthrough} <- verify_passthrough(payload) do
      {:ok, paid_at, _} = "#{payload["event_time"]}Z" |> DateTime.from_iso8601()

      Bling.Paddle.receipt()
      |> struct()
      |> Ecto.Changeset.change(%{
        paddle_subscription_id: str_int(payload["subscription_id"]),
        customer_id: passthrough["customer_id"],
        customer_type: passthrough["customer_type"],
        checkout_id: payload["checkout_id"],
        order_id: payload["order_id"],
        amount: payload["sale_gross"],
        tax: payload["payment_tax"],
        currency: payload["currency"],
        quantity: str_int(payload["quantity"]),
        receipt_url: payload["receipt_url"],
        paid_at: paid_at |> DateTime.truncate(:second)
      })
      |> Bling.Paddle.repo().insert!()
    else
      _ -> nil
    end
  end

  def handle(%{"alert_name" => "subscription_cancelled"} = payload) do
    subscription = verify_subscription(payload["subscription_id"])

    if !subscription do
      :ok
    else
      ends_at =
        cond do
          is_nil(subscription.ends_at) and Subscriptions.trial?(subscription) ->
            subscription.trial_ends_at

          is_nil(subscription.ends_at) ->
            {:ok, datetime, _} =
              DateTime.from_iso8601("#{payload["cancellation_effective_date"]} 00:00:00Z")

            datetime |> DateTime.truncate(:second)

          true ->
            subscription.ends_at
        end

      subscription
      |> Ecto.Changeset.change(%{
        ends_at: ends_at,
        paused_from: nil,
        paddle_status:
          if(Map.has_key?(payload, "status"),
            do: payload["status"],
            else: subscription.paddle_status
          )
      })
      |> Bling.Paddle.repo().update!()
    end
  end

  def handle(%{"alert_name" => "subscription_updated"} = payload) do
    subscription = verify_subscription(payload["subscription_id"])

    if !subscription do
      :ok
    else
      paused_from =
        if Map.has_key?(payload, "paused_from") do
          {:ok, timestamp, _} = "#{payload["paused_from"]}Z" |> DateTime.from_iso8601()
          timestamp |> DateTime.truncate(:second)
        end

      subscription
      |> Ecto.Changeset.change(%{
        paddle_plan:
          if(Map.has_key?(payload, "subscription_plan_id"),
            do: str_int(payload["subscription_plan_id"]),
            else: subscription.paddle_plan
          ),
        paddle_status:
          if(Map.has_key?(payload, "status"),
            do: payload["status"],
            else: subscription.paddle_status
          ),
        quantity:
          if(Map.has_key?(payload, "new_quantity"),
            do: str_int(payload["new_quantity"]),
            else: subscription.quantity
          ),
        paused_from: paused_from
      })
      |> Bling.Paddle.repo().update!()
    end
  end

  def handle(%{"alert_name" => "subscription_created"} = payload) do
    case verify_passthrough(payload) do
      {:ok, passthrough} ->
        trial_ends_at =
          if payload["status"] == "trialing" do
            {:ok, datetime, _} = DateTime.from_iso8601("#{payload["next_bill_date"]} 00:00:00Z")
            datetime |> DateTime.truncate(:second)
          else
            nil
          end

        struct(Bling.Paddle.subscription())
        |> Ecto.Changeset.change(%{
          customer_id: passthrough["customer_id"],
          customer_type: passthrough["customer_type"],
          name: passthrough["subscription_name"],
          paddle_id: str_int(payload["subscription_id"]),
          paddle_plan: str_int(payload["subscription_plan_id"]),
          paddle_status: payload["status"],
          quantity: str_int(payload["quantity"]),
          trial_ends_at: trial_ends_at
        })
        |> Bling.Paddle.repo().insert!()

      _ ->
        nil
    end
  end

  def handle(_, _), do: :ok

  defp verify_subscription(id) do
    Bling.Paddle.repo().get_by(Bling.Paddle.subscription(), paddle_id: id)
  end

  defp receipt_exists(receiptId) do
    Bling.Paddle.repo().get_by(Bling.Paddle.receipt(), order_id: receiptId)
  end

  defp verify_passthrough(payload) do
    passthrough = Map.get(payload, "passthrough")

    if passthrough do
      decoded = Jason.decode!(passthrough)
      required_keys = ["subscription_name", "customer_type", "customer_id"]
      has_keys? = Enum.all?(required_keys, fn key -> Map.has_key?(decoded, key) end)

      if has_keys? do
        {:ok, decoded}
      else
        {:error, "Invalid passthrough"}
      end
    else
      {:error, "Invalid passthrough"}
    end
  end

  defp str_int(value) when is_integer(value), do: value

  defp str_int(value) do
    {parsed, _} = Integer.parse(value)
    parsed
  end

  defp verify_signature(params) do
    if Mix.env() == :test do
      true
    else
      public_key = Application.get_env(:bling_paddle, :paddle)[:public_key]
      [public_key] = :public_key.pem_decode(public_key)
      public_key = :public_key.pem_entry_decode(public_key)

      signature = params |> Map.get("p_signature") |> Base.decode64!()

      body =
        params
        |> Map.drop(["p_signature"])
        |> Map.to_list()
        |> Enum.sort_by(fn {k, _v} -> k end, :asc)
        |> PhpSerializer.serialize()

      :public_key.verify(body, :sha, signature, public_key)
    end
  end
end
