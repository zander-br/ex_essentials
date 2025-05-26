defmodule Utilex.Web.Plugs.RequestValidator do
  @moduledoc """
  A `Plug` for validating request parameters using `Ecto.Changeset`.

  This plug enables modular and scalable validation of incoming request parameters by delegating the validation logic to a specific module (the `:validator`). It dynamically calls a function named after the current `:phoenix_action`, passing the request `params` as an argument. The function must return an `%Ecto.Changeset{}`.

  If the changeset is valid, the request proceeds as usual. If invalid, a `400 Bad Request` response is sent in the `application/problem+json` format.

  ## Options
    * `:validator` – **(required)** The module responsible for validation. It must implement a function for each action, with the same name as the `:phoenix_action` and an arity of 1 (accepting the `params`).

  ## Example Usage
  Given a controller with the `:create` action and a validator module:

      defmodule MyAppWeb.UserValidator do
        import Ecto.Changeset

        def create(params) do
          {%{}, %{name: :string, age: :integer}}
          |> cast(params, [:name, :age])
          |> validate_required([:name, :age])
        end
      end

  You can plug the validator into your controller or router pipeline:

      plug Utilex.Web.Plugs.RequestValidator, validator: MyAppWeb.UserValidator

  ## Error Response Format

  When validation fails, the response follows the structure inspired by
  [RFC 7807 - Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807):

      {
        "errors": [
          {
            "code": "invalid_parameter",
            "detail": "The 'age' field must be a positive integer",
            "title": "Invalid request parameters"
          }
        ],
        "status_code": 400
      }

  Each validation error includes:
    * `code` – configurable error code.
    * `detail` – human-readable description of the error.
    * `title` – general error title.

  ## Configuration
  You can customize certain aspects via your `config.exs`:

      config :utilex, :web_request_validator,
        json_library: Jason,
        error_code: :invalid_parameter,
        error_title: "Invalid request parameters"

  By default, it uses `Jason` for JSON encoding and the error code `:invalid_parameter`.

  ## Notes
    * This plug assumes Phoenix is being used and requires `:phoenix_action` to be set in `conn.private`.
    * `Ecto` is required for working with changesets.
  """

  require Logger

  import Plug.Conn

  alias Ecto.Changeset
  alias Plug.Conn

  @behaviour Plug
  @validator_arity 1
  @bad_request_status 400

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
    body = %{errors: errors, status_code: @bad_request_status}
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

  defp expand_field_errors({field, messages}),
    do: Enum.map(messages, &build_error_entry(field, &1))

  defp build_error_entry(field, message) do
    error_code = get_error_code()
    title = get_error_title()
    detail = "The '#{field}' field #{message}"
    %{code: error_code, detail: detail, title: title}
  end

  defp get_error_code, do: Keyword.get(get_config(), :error_code, :invalid_parameter)
  defp get_error_title, do: Keyword.get(get_config(), :error_title, "Invalid request parameters")

  defp json_library, do: Keyword.get(get_config(), :json_library, Jason)

  defp get_config, do: Application.get_env(:utilex, :web_request_validator, [])
end
