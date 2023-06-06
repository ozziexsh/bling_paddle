# Bling Paddle

Bling gives you an easy way to manage common billing scenarios in your own phoenix app through Paddle, making it a breeze to build custom subscription flows.

Looking for Stripe? Check out [Bling Stripe](https://hexdocs.pm/bling).

This package gives you modules and ecto schemas to manage common billing scenarios with Paddle. Since Paddle does not have much of an API, you will have to use the paddle checkout widgets to make the actual purchases and manage payment methods. Webhooks will then be handled which will sync the subscription data locally, allowing you to manage the subscriptions in your own app.

This package is influenced heavily by the amazing [Laravel Cashier](https://laravel.com/docs/10.x/cashier-paddle).

## Table of contents

- [Installation](#installation)
- [Customers](#customers)
- [Subscriptions](#subscriptions)
- [Failed payments](#failed-payments)
- [Webhooks](#webhooks)

## Installation

Add `bling_paddle` to your list of dependencies in `mix.exs`:

> Note: Until Bling reaches `1.0.0`, breaking changes will be pushed as minor version bumps. Make sure to pin the dependency to `~> 0.x.0` to ensure you only get patch releases.

```elixir
def deps do
  [
    {:bling_paddle, "~> 0.1.0"}
  ]
end
```

Configure your paddle credentials:

```elixir
config :bling_paddle, :paddle,
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

    has_many :subscriptions, MyApp.Subscriptions.Subscription,
      foreign_key: :customer_id,
      where: [customer_type: "user"],
      defaults: [customer_type: "user"]

    has_many :receipts, MyApp.Subscriptions.Receipt,
      foreign_key: :customer_id,
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
# e.g. place inside <head> tag in my_app_web/components/layouts/root.html.heex
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

That is all that is needed for installation!

Read on to learn how to use everything.

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

Paddle handles customers quite different from Stripe. The Laravel Cashier docs do an excellent job outlining the restrictions, and the same rules apply to Bling:

> In contrast to Stripe, Paddle users are unique across all of Paddle, not unique per Paddle account. Because of this, Paddle's API's do not currently provide a method to update a user's details such as their email address. When generating pay links, Paddle identifies users using the customer_email parameter. When creating a subscription, Paddle will try to match the user provided email to an existing Paddle user.
>
> In light of this behavior, there are some important things to keep in mind when using Cashier and Paddle. First, you should be aware that even though subscriptions in Cashier are tied to the same application user, they could be tied to different users within Paddle's internal systems. Secondly, each subscription has its own connected payment method information and could also have different email addresses within Paddle's internal systems (depending on which email was assigned to the user when the subscription was created).
>
> Therefore, when displaying subscriptions you should always inform the user which email address or payment method information is connected to the subscription on a per-subscription basis
>
> https://laravel.com/docs/10.x/cashier-paddle#user-identification

### Updating payment info

Payment information is specifc to each subscription and must be updated through the paddle checkout widget. You can generate a checkout widget url to update payment info for a subscription like so:

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

update_url = Bling.Paddle.Subscriptions.update_url(subscription)
```

You would then pass `update_url` to your paddle widget on the frontend, or redirect the user to that url:

```
<a
  href="#!"
  class="paddle_button"
  data-override={
    Bling.Paddle.Subscriptions.update_url(Bling.Paddle.Customers.subscription(@current_user))
  }
>
  Update Payment Method
</a>
```

### Fetching payment info

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

paddle_info = Bling.Paddle.Subscriptions.paddle_info(subscription)

payment_info = Map.get(paddle_info, "payment_information")
```

## Subscriptions

Note: Paddle does not allow updating subscriptions if they are cancelled or paused.

### Creating subscriptions

To create a subscription you can use the `Bling.Paddle.Customers.create_subscription/2` method to retrieve a URL to pass to the paddle checkout widget, or to redirect the user to.

Customer info will be prefilled based on the `paddle_customer_info/1` method in your `MyApp.Bling` module.

You can pass any valid params the api is expecting as keyword opts to this function:

https://developer.paddle.com/api-reference/3f031a63f6bae-generate-pay-link

```elixir
customer = MyApp.Accounts.get_user!(1)

pay_link = Bling.Paddle.Customers.create_subscription(customer, product_id: 12345)
```

Then either redirect to `pay_link` or use `pay_link` with the paddle checkout widget:

```
<a
  href="#!"
  class="paddle_button"
  data-override={Bling.Paddle.Customers.create_subscription(@current_user, product_id: 12345)}
>
  Buy Now!
</a>
```

### Subscription quantity

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

# all methods default to a quantity of 1
Bling.Paddle.Subscriptions.increment(subscription)
Bling.Paddle.Subscriptions.increment(subscription, quantity: 5)

Bling.Paddle.Subscriptions.increment_and_invoice(subscription)
Bling.Paddle.Subscriptions.decrement(subscription)

# sets to an exact quantity
Bling.Paddle.Subscriptions.update_quantity(subscription, quantity: 2)
```

### Cancelling

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

# cancels at the end of the billing period
Bling.Paddle.Subscriptions.cancel(subscription)
Bling.Paddle.Subscriptions.cancel_now(subscription)
Bling.Paddle.Subscriptions.cancel_at(subscription, DateTime.utc_now() |> DateTime.add(7, :day))

# or if you want to redirect to paddle/use the widget
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

Trials can be configured in Paddle when setting up the subscription plans so that the trials apply to all new subscriptions. Alternatively, you can pass `trial_days` to the create_subscription method to override the default trial period.

Doing this requires the customer to provide a payment method:

```elixir
customer = MyApp.Accounts.get_user!(1)

pay_link = Bling.Paddle.Customers.create_subscription(
  customer,
  product_id: 123,
  trial_days: 7,
)
```

If you'd like to provide no-card-upfront trials you can set the trial_ends_at column on the customer directly. Then to check if the user is on a trial you can use `Bling.Paddle.Customers.trial?` which will also take any subscription trials into account. If you want to check if the user is on a trial without a subscription, you can use the `Bling.Paddle.Customers.generic_trial?` method.

```elixir
customer = MyApp.Accounts.update_user(customer, %{
  trial_ends_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
})

# also checks for any subscription trials
Bling.Paddle.Customers.trial?(customer)

# only checks the customer for trial_ends_at
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

Bling.Customers.subscribed?(customer)
Bling.Customers.trial?(customer)
```

### Multiple subscriptions

If your app allows customers to be subscribed to multiple products at once, you can use the `name` parameter to differentiate between them.

```elixir
customer = MyApp.Accounts.get_user!(1)
subscription = Bling.Paddle.Customers.subscription(customer)

# subscriptions are created with a name of "default" if not provided
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

## Failed payments

You should let Paddle handle failed payments for you:

https://vendors.paddle.com/subscription-settings

Alternatively, you can use webhooks to listen for payment failures and handle them yourself.

## Webhooks

During the installation step you setup an endpoint to handle incoming events. This takes care of responding to some events like subscription creation and updating, which are required to use some of the methods provided by this library.

If you want to handle additional events, you can do that in the Bling module. We recommend handling events to notify your customers that there was an issue with their payment.

```elixir
defmodule MyApp.Bling do
  # ...

  def handle_paddle_webhook_event(event) do
    case event["alert_name"] do
      "subscription_payment_failed" ->
        # todo: send email
        nil

      _ ->
        nil
    end

    :ok
  end
end
```

## Contributing

Contributions are always welcome. Please open issues and submit pull requests with proper tests included.

### Running tests

The tests require you to have a `config/test.secret.exs` file setup. It should look like:

```elixir
import Config

config :bling_paddle,
  ecto_repos: [Bling.PaddleTest.Repo]

config :bling_paddle, Bling.PaddleTest.Repo,
  username: "postgres",
  password: "",
  database: "bling_paddle_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# this should be a real subscription plan id in your account
config :bling_paddle, :paddle_test_product, 12345

config :bling_paddle, :paddle,
  sandbox: true,
  vendor_id: 12345,
  vendor_auth_code: "your-auth-code"
```

Some tests hit the real Paddle api so make sure to enter a test api key. This also means the tests may take a bit to run.
