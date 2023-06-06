defmodule Bling.Paddle.Customers do
  alias Bling.Paddle.Util
  alias Bling.Paddle.Entity
  alias Bling.Paddle.Subscriptions

  @default_name "default"

  @doc """
  Fetches all subscriptions for a customer.
  """
  def subscriptions(customer) do
    repo = Entity.repo(customer)

    customer
    |> repo.preload(:subscriptions)
    |> Map.get(:subscriptions, [])
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  @doc """
  Fetches a single subscription for a customer by subscription name.

  ## Examples
      # gets subscription with name "default"
      subscription = Bling.Paddle.Customers.subscription(customer)

      # gets subscription with specific name
      subscription = Bling.Paddle.Customers.subscription(customer, name: "pro")
  """
  def subscription(customer, opts \\ []) do
    name = name_from_opts(opts)
    customer |> subscriptions() |> Enum.find(&(&1.name == name))
  end

  @doc """
  Returns whether or not the customer is subscribed, and that it is valid.

  ## Examples
      # checks if the customer is subscribed to the default subscription
      Bling.Paddle.Customers.subscribed?(customer)

      # checks if the customer is subscribed to a specific subscription
      Bling.Paddle.Customers.subscribed?(customer, name: "pro")
  """
  def subscribed?(customer, opts \\ []) do
    name = name_from_opts(opts)

    customer
    |> subscriptions()
    |> Enum.filter(&Subscriptions.valid?/1)
    |> Enum.map(& &1.name)
    |> Enum.member?(name)
  end

  @doc """
  Returns true if the customer is on a generic trial or if the specified subscription is on a trial.

  ## Examples

      # checks trial_ends_at on customer and "default" subscription
      Bling.Paddle.Customers.trial?(customer)

      # checks trial_ends_at on customer and "swimming" subscription
      Bling.Paddle.Customers.trial?(customer, name: "swimming")
  """
  def trial?(customer, opts \\ []) do
    subscription = subscription(customer, opts)

    cond do
      generic_trial?(customer) -> true
      is_nil(subscription) -> false
      Subscriptions.trial?(subscription) -> true
      true -> false
    end
  end

  @doc """
  Returns whether the customer is on a generic trial.

  Checks the `trial_ends_at` column on the customer.
  """
  def generic_trial?(%{trial_ends_at: nil} = _customer), do: false

  def generic_trial?(customer) do
    ends_at = DateTime.compare(customer.trial_ends_at, DateTime.utc_now())

    ends_at == :gt
  end

  @doc """
  Returns a payment link for a subscription to be redirected to or used in the Paddle widget.

  You can pass any valid parameter the Paddle api is expecting as a keyword option:

  https://developer.paddle.com/api-reference/3f031a63f6bae-generate-pay-link

  ## Examples

      # simple
      url = create_subscription(
        customer,
        product_id: "abcd"
      )

      # multiple subscriptions
      url = create_subscription(
        customer,
        name: "swimming",
        product_id: "abcd"
      )

      # extra api options
      url = create_subscription(
        customer,
        product_id: "abcd",
        trial_days: 10,
        coupon_code: "something"
      )
  """
  def create_subscription(customer, opts) do
    name = name_from_opts(opts)
    payload = Keyword.drop(opts, [:name])
    metadata = Keyword.get(opts, :passthrough, %{})

    passthrough =
      Map.merge(
        %{
          subscription_name: name
        },
        metadata
      )

    payload =
      payload
      |> Keyword.merge(passthrough: passthrough)
      |> maybe_add_prices()

    generate_pay_link(customer, payload)
  end

  @doc """
  Generate a Paddle payment link.

  If you are wanting to create a subscription, use `Bling.Paddle.Customers.create_subscription/2` instead
  to ensure the proper passthrough parameters are being set.

  You can pass any valid parameter the Paddle api is expecting as a keyword option:

  https://developer.paddle.com/api-reference/3f031a63f6bae-generate-pay-link

  Uses email, country, and postcode keys from map returned in your `MyApp.Bling.paddle_customer_info(customer)` function.
  """
  def generate_pay_link(customer, opts) do
    bling = Entity.bling(customer)
    customer_params = Util.maybe_call({bling, :paddle_customer_info, [customer]}, %{})

    passthrough =
      opts
      |> Keyword.get(:passthrough, %{})
      |> Map.put(:customer_id, customer.id)
      |> Map.put(:customer_type, bling.customer_type_from_struct(customer))
      |> Jason.encode!()

    opts
    |> Keyword.put_new(:customer_email, Map.get(customer_params, :email))
    |> Keyword.put_new(:customer_country, Map.get(customer_params, :country))
    |> Keyword.put_new(:customer_postcode, Map.get(customer_params, :postcode))
    |> Keyword.merge(passthrough: passthrough)
    |> Enum.into(%{})
    |> Bling.Paddle.Api.generate_pay_link()
    |> Map.get("url")
  end

  # Paddle will immediately charge the plan price if trial_days are passed here
  # and no trial days are configured via the Paddle dashboard. So we need to
  # explicitly set the prices to 0 for the first charge. If there's no trial,
  # we use the recurring_prices to charge the user immediately.
  defp maybe_add_prices(payload) do
    cond do
      Keyword.has_key?(payload, :prices) ->
        payload

      not Keyword.has_key?(payload, :trial_days) ->
        payload

      true ->
        plan = payload[:product_id]
        trialing? = payload[:trial_days] != 0
        response = Bling.Paddle.Api.subscription_plans(%{plan: plan}) |> List.first()
        key = if trialing?, do: "initial_price", else: "recurring_price"
        prices = Map.get(response, key, %{})

        prices =
          prices
          |> Enum.reduce([], fn {currency, price}, acc ->
            amount = if trialing?, do: 0, else: price
            ["#{currency}:#{amount}" | acc]
          end)
          |> Enum.reverse()

        Keyword.put(payload, :prices, prices)
    end
  end

  defp name_from_opts(opts), do: Keyword.get(opts, :name, @default_name)
end
