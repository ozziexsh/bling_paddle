defmodule Bling.Paddle.Http do
  @moduledoc false
  @callback post(term, term, term) :: {:atom, term}

  def post(url, data, headers), do: impl().post(url, data, headers)
  def impl(), do: Application.get_env(:bling_paddle, :http_lib, HTTPoison)
end
