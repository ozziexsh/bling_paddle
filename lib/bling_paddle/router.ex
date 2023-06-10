defmodule Bling.Paddle.Router do
  defmacro paddle_webhook_route(path) do
    quote do
      scope unquote(path), as: false, alias: false do
        Phoenix.Router.post(
          "/",
          Bling.Paddle.Controllers.PaddleWebhookController,
          :webhook
        )
      end
    end
  end
end
