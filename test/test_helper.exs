ExUnit.start()
Faker.start()

{:ok, _pid} = Bling.PaddleTest.Repo.start_link()
{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Bling.PaddleTest.Repo, :temporary)

Ecto.Adapters.SQL.Sandbox.mode(Bling.PaddleTest.Repo, :manual)
