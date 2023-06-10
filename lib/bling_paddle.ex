defmodule Bling.Paddle do
  @type customer :: any

  @callback paddle_customer_info(customer) :: map
  @callback handle_paddle_webhook_event(term) :: any

  def bling do
    Application.get_env(:bling_paddle, :bling)
  end

  def repo do
    Application.get_env(:bling_paddle, :repo)
  end

  def customers do
    Application.get_env(:bling_paddle, :customers, [])
  end

  def subscription do
    Application.get_env(:bling_paddle, :subscription)
  end

  def receipt do
    Application.get_env(:bling_paddle, :receipt)
  end

  def currency do
    Application.get_env(:bling_paddle, :paddle, [])
    |> Keyword.get(:currency, "USD")
  end

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

  def script_tags() do
    vendor_id = Application.get_env(:bling_paddle, :paddle)[:vendor_id]
    sandbox? = Application.get_env(:bling_paddle, :paddle)[:sandbox] || false
    sandbox_str = if sandbox?, do: "Paddle.Environment.set('sandbox');", else: ""

    """
    <script src="https://cdn.paddle.com/paddle/paddle.js"></script>
    <script type="text/javascript">
      #{sandbox_str}

      Paddle.Setup({ vendor: #{vendor_id} });
    </script>
    """
  end

  def deactivate_past_due?() do
    opts = Application.get_env(:bling_paddle, :paddle, [])
    val = Keyword.get(opts, :deactivate_past_due?, true)

    val == true
  end
end
