# Bling Paddle

Bling gives you an easy way to manage common billing scenarios in your own phoenix app through Paddle, making it a breeze to build custom subscription flows.

Looking for Stripe? Check out [Bling Stripe](https://hexdocs.pm/bling).

This package gives you ecto schemas and modules to manage common billing scenarios with Paddle. You will use the paddle checkout widgets to make purchases and manage payment methods which will sync through webhooks, allowing you to query customer subscriptions locally without hitting the api.

This package is influenced heavily by the amazing [Laravel Cashier](https://laravel.com/docs/10.x/cashier-paddle).

## Installation

Add `bling_paddle` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bling_paddle, "~> 0.1.0"}
  ]
end
```

Configure your paddle credentials:

```elixir
config :bling, :paddle,
  sandbox: true, # make sure to set to false when in production
  vendor_id: 12345,
  vendor_auth_code: "auth-code-here",
  public_key: """
  -----BEGIN PUBLIC KEY-----
  your paddle webhook public key here
  -----END PUBLIC KEY-----
  """
```

Run the install command to create the migrations and schemas:

```shell
mix bling.paddle.install
```

Create a migration to add the required columns to your customer table. The command in the example below uses the "users" table but you could use anything, like "teams".

```shell
mix bling.paddle.customer users
```

Once the migration has been ran we can add the following to the corresponding module for the table we provided to the previous command:

```elixir
defmodule MyApp.Accounts.User do
  # ...

  schema "users" do
    # ...

    field :trial_ends_at, :utc_datetime

    has_many :subscriptions, PaddleDemo.Subscriptions.Subscription,
      where: [customer_type: "user"],
      defaults: [customer_type: "user"]

    has_many :receipts, PaddleDemo.Subscriptions.Receipt,
      where: [customer_type: "user"],
      defaults: [customer_type: "user"]
  end
end
```

We can then register this customer in our Bling module that was generated for us:

```elixir
# lib/my_app/bling.ex
defmodule MyApp.Bling do
  use Bling.Paddle,
    customers: [user: MyApp.Accounts.User]
    # ...
```

Install the paddle js required to show the checkout widgets somewhere in your layout:

```elixir
<%= raw(Bling.Paddle.script_tags()) %>
```

Open up your router file and add the Bling route for handling paddle webhooks:

```elixir
defmodule MyAppWeb.Router do
  import Bling.Paddle.Router

  # ... your routes

  paddle_webhook_route("/webhooks/paddle", bling: MyApp.Bling)
end
```

Don't forget to register your endpoint in Paddle's webhook dashboard and add at least the following events:

- Subscription Created
- Subscription Updated
- Subscription Cancelled
- Subscription Payment Success
- Payment Success

## Bling module

The Bling module installed in your project has a few helpful methods for deriving information:

```elixir
MyApp.Accounts.User = MyApp.Bling.module_from_customer_type("user")
"user" = MyApp.Bling.customer_type_from_struct(%MyApp.Accounts.User{})
```

You can also implement these methods in your `MyApp.Bling` module to extend functionality:

- `def paddle_customer_info(customer)`
  - return a map with keys `email`, `country`, and `postcode` to be used when creating a new subscription in paddle.
- `def handle_paddle_webhook_event(event)`
  - handle your own paddle webhook events.

## Customers

### Updating payment info

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

update_url = Bling.Paddle.Subscriptions.update_url(subscription)
```

## Subscriptions

### Creating subscriptions

Uses info from paddle_customer_info

Can pass any valid params as keyword opts https://developer.paddle.com/api-reference/3f031a63f6bae-generate-pay-link

```elixir
customer = MyApp.Accounts.get_user!(1)

pay_link = Bling.Paddle.Customers.create_subscription_link(customer, product_id: 12345)
```

Then render pay link in your app

### Subscription quantity

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

Bling.Paddle.Subscriptions.increment(subscription, quantity: 1)
Bling.Paddle.Subscriptions.increment_and_invoice(subscription, quantity: 1)
Bling.Paddle.Subscriptions.decrement(subscription, quantity: 1)
Bling.Paddle.Subscriptions.update_quantity(subscription, quantity: 2)
```

### Cancelling

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

Bling.Paddle.Subscriptions.cancel(subscription)
Bling.Paddle.Subscriptions.cancel_now(subscription)
Bling.Paddle.Subscriptions.cancel_at(subscription, DateTime.utc_now() |> DateTime.add(7, :day))

cancel_url = Bling.Paddle.Subscriptions.cancel_url(subscription)
```

### Pausing

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

Bling.Paddle.Subscriptions.pause(subscription)
Bling.Paddle.Subscriptions.unpause(subscription)
```

### Trials

```elixir
customer = MyApp.Accounts.get_user!(1)

pay_link = Bling.Paddle.Customers.create_subscription(
  customer,
  product_id: 123,
  trial_days: 7,
)

customer = MyApp.Accounts.update_user(customer, %{
  trial_ends_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
})

Bling.Paddle.Customers.trial?(customer)
Bling.Paddle.Customers.generic_trial?(customer)
```

### Changing plans

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

Bling.Paddle.Subscriptions.swap(subscription, plan_id: 123)
Bling.Paddle.Subscriptions.swap_and_invoice(subscription, plan_id: 123)
```

### Checking status

```elixir
alias Bling.Paddle.Subscriptions
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

Subscriptions.has_plan?(subscription, 123)
Subscriptions.valid?(subscription)
Subscriptions.active?(subscription)
Subscriptions.past_due?(subscription)
Subscriptions.recurring?(subscription)
Subscriptions.paused?(subscription)
Subscriptions.paused_grace_period?(subscription)
Subscriptions.cancelled?(subscription)
Subscriptions.ended?(subscription)
Subscriptions.trial?(subscription)
Subscriptions.expired_trial?(subscription)
Subscriptions.grace_period?(subscription)
```

### Multiple subscriptions

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

pay_link = Bling.Paddle.Customers.create_subscription(
  customer,
  name: "default",
  product_id: 123
)

pay_link = Bling.Paddle.Customers.create_subscription(
  customer,
  name: "swimming",
  product_id: 456
)

Bling.Paddle.Customers.subscription(customer, name: "swimming")
Bling.Paddle.Customers.subscribed?(customer, name: "swimming")
```
