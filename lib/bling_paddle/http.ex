defmodule Bling.Paddle.Http do
  @moduledoc false
  @type headers :: [{binary, binary}]
  @type url :: binary

  @callback post(url, term, headers) :: {:atom, term}
  @callback get(url, headers) :: {:atom, term}

  def post(url, data, headers), do: impl().post(url, data, headers)
  def get(url, headers), do: impl().get(url, headers)
  def impl(), do: Application.get_env(:bling_paddle, :http_lib, HTTPoison)
end
