# Upgrading

## v0.1.0 -> v0.2.0

v0.2.0 moved the options that you originally passed to `use Bling.Paddle` into the config instead. This removes the need for `use Bling` altogether.

1. Copy the config from `use Bling` in `my_app/lib/bling.ex` to `my_app/config/config.exs`:

```elixir
config :bling_paddle,
  bling: MyApp.Bling,
  repo: MyApp.Repo,
  customers: [
    user: MyApp.Accounts.User
  ],
  subscription: MyApp.Subscriptions.Subscription,
  receipt: MyApp.Subscriptions.Receipt
```

2. Delete the `use Bling.Paddle` statement from `my_app/lib/bling.ex`

```diff
defmodule PaddleCheckout.Bling do
-  use Bling.Paddle,
-    bling: MyApp.Bling,
-    repo: MyApp.Repo,
-    customers: [
-      user: MyApp.Accounts.User
-    ],
-    subscription: MyApp.Subscriptions.Subscription,
-    receipt: MyApp.Subscriptions.Receipt

  def paddle_customer_info(customer) do
    # valid map keys are `email`, `country`, and `postcode`
    case customer do
      %PaddleCheckout.Accounts.User{} -> %{email: customer.email}
      _ -> %{}
    end
  end

  def handle_paddle_webhook_event(_event) do
    :ok
  end
end
```

3. Implement the new `Bling.Paddle` behaviour to ensure you always have the required functions

```diff
defmodule PaddleCheckout.Bling do
+ @behaviour Bling.Paddle

+ @impl Bling.Paddle
  def paddle_customer_info(customer) do
    # valid map keys are `email`, `country`, and `postcode`
    case customer do
      %PaddleCheckout.Accounts.User{} -> %{email: customer.email}
      _ -> %{}
    end
  end

+ @impl Bling.Paddle
  def handle_paddle_webhook_event(_event) do
    :ok
  end
end
```

4. Remove the Bling plug from your router as it is no longer needed or exported

```diff
pipeline :browser do
  plug(:accepts, ["html"])
  plug(:fetch_session)
  plug(:fetch_live_flash)
  plug(:put_root_layout, {PaddleCheckoutWeb.Layouts, :root})
  plug(:protect_from_forgery)
  plug(:put_secure_browser_headers)
  plug(:fetch_current_user)
- plug(Bling.Paddle.Plug, bling: MyApp.Bling)
end
```

5. `module_from_customer_type` and `customer_type_from_struct` moved from your local `MyApp.Bling` module to the package `Bling.Paddle` module.

Simply change the module name anywhere you use these two funcs:

```diff
- MyApp.Bling.module_from_customer_type("user")
+ Bling.Paddle.module_from_customer_type("user")

- MyApp.customer_type_from_struct(customer)
+ Bling.Paddle.customer_type_from_struct(customer)
```
