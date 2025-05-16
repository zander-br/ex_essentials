defmodule Utilex.Web.Plugs.RequestValidator do
  @moduledoc """
  A `Plug` module for validating request parameters using action-specific Ecto changesets.

  This plug allows developers to enforce input validation in a modular and scalable way
  by delegating validation logic to separate modules. The plug will call a function named
  after the current `:phoenix_action`, passing the request `params` to it. It expects
  that the function returns an `%Ecto.Changeset{}`.

  If the changeset is valid, the connection continues as usual. If invalid, a JSON response
  with a `400 Bad Request` status is returned, using the media type `application/problem+json`.

  ## Options

    * `:validator` - (required) The module that implements the changeset validation logic.
      This module should define a function for each Phoenix action it handles, matching
      the name of the action and accepting a single argument (the request params).

  ## Usage

  Given a controller action `:create`, and a validator module:

  ```elixir
  defmodule MyAppWeb.UserValidator do
    import Ecto.Changeset

    def create(params) do
      {%{}, %{name: :string, age: :integer}}
      |> cast(params, [:name, :age])
      |> validate_required([:name, :age])
    end
  end
  ```

  You can plug the validator in your router or controller pipeline:

  ```elixir
  plug Utilex.Web.Plugs.RequestValidator, validator: MyAppWeb.UserValidator
  ```

  ## Error Response Format

  When validation fails, the response will follow the structure inspired by
  [RFC 7807 - Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807):

  ```json
  {
    "type": "https://example.net/validation_error",
    "title": "Your request parameters didn't validate.",
    "errors": [
      { "field": "age", "reason": "must be a positive integer" },
      { "field": "age", "reason": "is required" },
      { "field": "color", "reason": "must be 'green', 'red' or 'blue'" }
    ]
  }
  ```

  Each validation error is represented as an object with a `field` field corresponding to the parameter,
  and a `reason` field containing the human-readable explanation.

  ## Configuration

  You can customize the JSON library used for encoding by setting it in your config:

  ```elixir
  config :utilex, :web_request_validator,
    json_library: Jason,
    error_type: "https://my_domain/validation_error",
    error_title: "Validation Error"
  ```

  Defaults to `Jason` if not configured.

  ## Notes

  This plug assumes Phoenix is being used and depends on `:phoenix_action` being set
  in `conn.private`. It also requires Ecto to be available for working with changesets.
  """

  require Logger

  import Plug.Conn

  alias Ecto.Changeset
  alias Plug.Conn

  @behaviour Plug
  @validator_arity 1

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    validator = opts |> Keyword.get(:validator) |> load_validator()
    run_validate(conn, validator)
  end

  defp load_validator(validator) do
    case Code.ensure_loaded(validator) do
      {:module, module} -> module
    end
  end

  defp run_validate(conn = %Conn{private: private, params: params}, validator) do
    action = Map.get(private, :phoenix_action)

    if function_exported?(validator, action, @validator_arity) do
      case apply(validator, action, [params]) do
        %Changeset{valid?: true} -> conn
        changeset -> on_error(conn, changeset)
      end
    else
      Logger.info("Validator #{inspect(validator)} does not have a function #{action}/#{@validator_arity}")
      conn
    end
  end

  defp on_error(conn, changeset) do
    errors = normalize_errors(changeset)
    type = get_error_type()
    title = get_error_title()
    body = %{type: type, title: title, errors: errors}
    json = json_library().encode_to_iodata!(body)

    conn
    |> put_status(:bad_request)
    |> put_resp_header("content-type", "application/problem+json")
    |> send_resp(:bad_request, json)
    |> halt()
  end

  defp normalize_errors(changeset) do
    changeset
    |> Changeset.traverse_errors(&replace_placeholders/1)
    |> translate_errors()
  end

  defp replace_placeholders({msg, opts}), do: Enum.reduce(opts, msg, &replace_placeholder/2)

  defp replace_placeholder({key, value}, acc), do: String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)

  defp translate_errors(errors), do: Enum.flat_map(errors, &expand_field_errors/1)

  defp expand_field_errors({field, messages}), do: Enum.map(messages, &build_error_entry(field, &1))

  defp build_error_entry(field, message), do: %{field: to_string(field), reason: message}

  defp get_error_type, do: Keyword.get(get_config(), :error_type, "https://example.net/validation_error")

  defp get_error_title, do: Keyword.get(get_config(), :error_title, "Your request parameters didn't validate.")

  defp json_library, do: Keyword.get(get_config(), :json_library, Jason)

  defp get_config, do: Application.get_env(:utilex, :web_request_validator, [])
end
