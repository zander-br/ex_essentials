defmodule ExEssentials.Web.Plugs.RequestValidator do
  @moduledoc """
  A `Plug` for validating request parameters using `Ecto.Changeset`.

  This plug enables modular and scalable validation of incoming request parameters by delegating the validation logic to a specific module (the `:validator`). It dynamically calls a function named after the current `:phoenix_action`, passing the request `params` as an argument. The function must return an `%Ecto.Changeset{}`.

  If the changeset is valid, the request proceeds as usual. If invalid, a `400 Bad Request` response is sent in the `application/problem+json` format.

  ## Options
    * `:validator` – **(required)** The module responsible for validation. It must implement a function for each action, with the same name as the `:phoenix_action` and an arity of 1 (accepting the `params`).

  ## Example Usage
  Given a controller with the `:create` action and a validator module:

      defmodule MyAppWeb.Validators.Types.User.Preferences do
        use Ecto.Schema

        import Ecto.Changeset

        @themes ~w(light dark)
        @languages ~w(en pt-br)
        @fields ~w(theme language)a

        @primary_key false
        embedded_schema do
          field(:theme, :string)
          field(:language, :string)
        end

        def changeset(schema, params) do
          schema
          |> cast(params, @fields)
          |> validate_required(@fields)
          |> validate_inclusion(:theme, @themes)
          |> validate_inclusion(:language, @languages)
        end
      end

      defmodule MyAppWeb.Validators.Types.User.Course do
        use Ecto.Schema

        import Ecto.Changeset

        @fields ~w(name duration level)a
        @levels ~w(beginner intermediary advanced)

        @primary_key false
        embedded_schema do
          field(:name, :string)
          field(:duration, :integer)
          field(:level, :string)
        end

        def changeset(schema, params) do
          schema
          |> cast(params, @fields)
          |> validate_required(@fields)
          |> validate_number(:duration, greater_than: 0)
          |> validate_inclusion(:level, @levels)
        end
      end

      defmodule MyAppWeb.Validators.User do
        use Ecto.Schema

        import Ecto.Changeset

        alias MyAppWeb.Validators.Types.User.Course
        alias MyAppWeb.Validators.Types.User.Preferences
        alias MyAppWeb.Validators.User

        @fields ~w(name email)a

        schema "users" do
          field(:name, :string)
          field(:email, :string)

          embeds_one(:preferences, Preferences)
          embeds_many(:courses, Course)
        end

        def create(params) do
          %User{}
          |> cast(params, @fields)
          |> validate_required(@fields)
          |> cast_embed(:preferences, required: true)
          |> cast_embed(:courses, required: true)
        end
      end

  You can plug the validator into your controller or router pipeline:

      plug ExEssentials.Web.Plugs.RequestValidator, validator: MyAppWeb.Validators.User

  ## Error Response Format

  When validation fails, the response follows the structure inspired by
  [RFC 7807 - Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807):

      {
        "errors": [
          {
            "code": "invalid_parameter",
            "detail": "The 'name' field can't be blank",
            "title": "Invalid request parameters"
          },
          {
            "code": "invalid_parameter",
            "detail": "The 'courses.[1].level' field is invalid",
            "title": "Invalid request parameters"
          },
          {
            "code": "invalid_parameter",
            "detail": "The 'preferences.language' field can't be blank",
            "title": "Invalid request parameters"
          },
          {
            "code": "invalid_parameter",
            "detail": "The 'preferences.theme' field is invalid",
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

      config :ex_essentials, :web_request_validator,
        json_library: Jason,
        error_code: :invalid_parameter,
        error_title: "Invalid request parameters"

  By default, the module uses Jason to encode JSON responses, assigning the
  error code :invalid_parameter and the error title "Invalid request parameters".

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

  defp run_validate(%Conn{private: private, params: params} = conn, validator) do
    action = Map.get(private, :phoenix_action)

    if function_exported?(validator, action, @validator_arity) do
      case apply(validator, action, [params]) do
        %Changeset{valid?: true} -> conn
        changeset -> respond_with_validation_errors(conn, changeset)
      end
    else
      Logger.info("Validator #{inspect(validator)} does not have a function #{action}/#{@validator_arity}")
      conn
    end
  end

  defp respond_with_validation_errors(conn, changeset) do
    errors = traverse_and_format_errors(changeset)
    body = %{errors: errors, status_code: @bad_request_status}
    json = get_json_encoder().encode_to_iodata!(body)

    conn
    |> put_resp_header("content-type", "application/problem+json")
    |> send_resp(:bad_request, json)
    |> halt()
  end

  defp traverse_and_format_errors(%Changeset{changes: changes} = changeset) do
    changeset
    |> Changeset.traverse_errors(&interpolate_error_placeholders/1)
    |> transform_errors_to_response_format(changes)
  end

  defp interpolate_error_placeholders({msg, opts}), do: Enum.reduce(opts, msg, &replace_placeholder_token/2)

  defp replace_placeholder_token({key, value}, acc), do: String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)

  defp transform_errors_to_response_format(errors, changes) do
    errors
    |> Enum.map(&handle_field_error_with_context(&1, changes))
    |> List.flatten()
  end

  defp handle_field_error_with_context({field, detail}, changes) do
    field_changed = Map.get(changes, field)
    generate_field_error_details({field, detail}, field_changed)
  end

  defp generate_field_error_details({field, details}, field_change)
       when is_list(details) and is_list(field_change) do
    details
    |> Enum.with_index()
    |> Enum.filter(&error_detail_present?/1)
    |> Enum.map(&generate_indexed_nested_errors(&1, field))
  end

  defp generate_field_error_details({field, details}, _field_change) when is_list(details),
    do: Enum.map(details, &convert_reason_to_error_detail(field, &1))

  defp generate_field_error_details({field, detail}, _field_change) do
    detail
    |> Map.keys()
    |> Enum.map(&convert_nested_field_errors(field, detail, &1))
  end

  defp convert_reason_to_error_detail(field, reason),
    do: create_error_response_detail(field, reason)

  defp convert_nested_field_errors(field, detail, nested_field) do
    errors = Map.get(detail, nested_field, [])
    Enum.map(errors, &generate_nested_error_detail(field, nested_field, &1))
  end

  defp error_detail_present?({detail, _index}), do: detail != %{}

  defp generate_indexed_nested_errors({detail, index}, field) do
    detail
    |> Map.keys()
    |> Enum.map(&convert_indexed_nested_field_errors(field, detail, &1, index))
  end

  defp convert_indexed_nested_field_errors(field, detail, nested_field, index) do
    errors = Map.get(detail, nested_field, [])
    Enum.map(errors, &create_indexed_nested_error_response(field, nested_field, &1, index))
  end

  defp generate_nested_error_detail(field, nested_field, message),
    do: create_error_response_detail("#{field}.#{nested_field}", message)

  defp create_indexed_nested_error_response(field, nested_field, message, nested_index) do
    detail = "The '#{field}.[#{nested_index}].#{nested_field}' field #{message}"
    error_code = fetch_error_code_from_config()
    title = fetch_error_title_from_config()
    %{code: error_code, detail: detail, title: title}
  end

  defp create_error_response_detail(field, reason) do
    error_code = fetch_error_code_from_config()
    title = fetch_error_title_from_config()
    detail = "The '#{field}' field #{reason}"
    %{code: error_code, detail: detail, title: title}
  end

  defp fetch_error_code_from_config, do: Keyword.get(fetch_validator_config(), :error_code, :invalid_parameter)

  defp fetch_error_title_from_config,
    do: Keyword.get(fetch_validator_config(), :error_title, "Invalid request parameters")

  defp get_json_encoder, do: Keyword.get(fetch_validator_config(), :json_library, Jason)

  defp fetch_validator_config, do: Application.get_env(:ex_essentials, :web_request_validator, [])
end
