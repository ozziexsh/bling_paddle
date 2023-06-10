import Config

config :bling_paddle,
  bling: Bling.PaddleTest.ExampleBling,
  repo: Bling.PaddleTest.Repo,
  subscription: Bling.PaddleTest.Subscription,
  receipt: Bling.PaddleTest.Receipt,
  customers: [user: Bling.PaddleTest.User]

import_config("test.secret.exs")
