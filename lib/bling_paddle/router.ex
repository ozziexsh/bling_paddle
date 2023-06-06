defmodule Bling.Paddle.Router do
  defmacro paddle_webhook_route(path, opts) do
    quote do
      pipeline :bling_paddle_webhook do
        plug(Bling.Paddle.Plug, bling: unquote(opts[:bling]))
      end

      scope unquote(path), as: false, alias: false do
        pipe_through(:bling_paddle_webhook)

        Phoenix.Router.post(
          "/",
          Bling.Paddle.Controllers.PaddleWebhookController,
          :webhook
        )
      end
    end
  end
end
