defmodule Utilex.Web.Plugs.RequestValidatorTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias Utilex.Web.Plugs.RequestValidator

  defmodule Users do
    use Ecto.Schema

    import Ecto.Changeset

    alias __MODULE__

    schema "users" do
      field(:name, :string)
      field(:email, :string)
    end

    def create(params) do
      %Users{}
      |> cast(params, ~w(name email)a)
      |> validate_required(~w(name email)a)
    end
  end

  describe "call/2" do
    setup do
      opts = RequestValidator.init(validator: Users)
      params = %{"name" => "Joe Doe", "email" => "joe.doe@mail.com"}
      %{opts: opts, params: params}
    end

    test "should return a conn with state :unset when the data is successfully validated",
         %{opts: opts, params: valid_params} do
      conn =
        conn(:post, "/api/users", valid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with state :unset when validator does not have a validate function",
         %{opts: opts, params: valid_params} do
      conn =
        conn(:post, "/api/users", valid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :update)
        |> RequestValidator.call(opts)

      assert conn.state == :unset
    end
  end
end
