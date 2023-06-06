defmodule Bling.PaddleTest.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Bling.PaddleTest.Repo
      import Bling.PaddleTest.RepoCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Bling.PaddleTest.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def create_user(data \\ %{}) do
    changes =
      Map.merge(
        %{
          email: Faker.Internet.email()
        },
        data
      )

    %Bling.PaddleTest.User{}
    |> Ecto.Changeset.change(changes)
    |> Bling.PaddleTest.Repo.insert!()
  end

  def create_subscription(customer, data \\ %{}) do
    changes =
      Map.merge(
        %{
          name: "default",
          paddle_id: Faker.random_between(1, 1000),
          paddle_status: "active",
          paddle_plan: Faker.random_between(1, 1000),
          quantity: 1,
          trial_ends_at: nil,
          paused_from: nil,
          ends_at: nil
        },
        data
      )

    Ecto.build_assoc(customer, :subscriptions)
    |> Ecto.Changeset.change(changes)
    |> Bling.PaddleTest.Repo.insert!()
  end

  def create_receipt(customer, data \\ %{}) do
    changes =
      Map.merge(
        %{
          paddle_subscription_id: Faker.random_between(1, 1000),
          checkout_id: Ecto.UUID.generate(),
          order_id: Ecto.UUID.generate(),
          amount: "10.00",
          tax: "1.40",
          currency: "USD",
          quantity: 1,
          receipt_url: "http://localhost:4000/receipt",
          paid_at: DateTime.utc_now() |> DateTime.truncate(:second)
        },
        data
      )

    Ecto.build_assoc(customer, :receipts)
    |> Ecto.Changeset.change(changes)
    |> Bling.PaddleTest.Repo.insert!()
  end
end
