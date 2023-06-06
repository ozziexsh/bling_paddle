defmodule Bling.Paddle do
  defmacro __using__(opts) do
    opts = Keyword.put(opts, :caller, __CALLER__.module)

    quote do
      @repo unquote(opts[:repo])
      @customers unquote(opts[:customers])
      @subscription unquote(opts[:subscription])
      @receipt unquote(opts[:receipt])

      def repo, do: @repo
      def customers, do: @customers
      def subscription, do: @subscription
      def receipt, do: @receipt

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

      for entity <- [@subscription, @receipt | Keyword.values(@customers)] do
        defimpl Bling.Paddle.Entity, for: entity do
          def repo(_entity), do: unquote(opts[:repo])
          def bling(_entity), do: unquote(opts[:caller])
        end
      end
    end
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
