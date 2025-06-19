defmodule ExEssentials.Web.Plugs.DisableServices do
  @moduledoc """
  A `Plug` that conditionally disables specific controller actions based on a feature flag,
  with optional support for group-based evaluation using `FunWithFlags`.

  ## Overview

  This plug allows developers to temporarily disable specific Phoenix actions
  (e.g., `:create`, `:delete`) by checking if a feature flag is enabled for the current context (typically, the current user or realm).

  It works by intercepting the connection and returning a `503 Service Unavailable`
  response if the feature flag is enabled and the requested action is among the disabled ones.

  Group-based targeting is supported through `FunWithFlags`, using a struct that includes
  the current user as `current_user`.

  ## Configuration

  You must provide the following options when using the plug:

    * `:disabled_actions` – a list of controller actions (atoms) that should be disabled if the flag is active.
    * `:flag_name` – the name of the feature flag to check (defaults to `:disable_services_enabled`).

  This plug uses `FunWithFlags.enabled?/2` with a custom context struct that supports group checks via `FunWithFlags.Group`.

  ## Dependencies

  To use this plug, your application must be configured with:

  ```elixir
  {:fun_with_flags, "~> 1.13"},
  {:ecto_sql, "~> 3.4"},
  {:postgrex, ">= 0.0.0"},
  ```

  And you must configure the `FunWithFlags` adapter to use Ecto with a repo.

  ## Usage

  ### Simple usage (default behavior)

  By default, the plug uses `conn.assigns.user_name` or `conn.params["user_name"]` to resolve the group.

  ```elixir
  plug ExEssentials.Web.Plugs.DisableServices,
    disabled_actions: [:create, :delete],
    flag_name: :services_disabled
  ```

  ### Customized usage with `use` and `@impl`

  To change how the group name is extracted from the connection (e.g., use `realm` instead of `user_name`),
  you can define your own module and override the `get_current_user/1` callback:

  ```elixir
  defmodule MyApp.Web.Plugs.DisableServices do
    use ExEssentials.Web.Plugs.DisableServices

    @impl ExEssentials.Web.Plugs.DisableServices
    def get_current_user(%Plug.Conn{assigns: %{realm: realm}}), do: realm
    def get_current_user(%Plug.Conn{params: params}), do: Map.get(params, "realm")
    def get_current_user(_), do: nil
  end
  ```

  And in your router or endpoint:

  ```elixir
  plug MyApp.Web.Plugs.DisableServices,
    disabled_actions: [:create, :delete],
    flag_name: :services_disabled
  ```

  ## Example with `FunWithFlags`

  To enable or disable the flag at runtime:

  ```elixir
  FunWithFlags.enable(:services_disabled)
  FunWithFlags.disable(:services_disabled, for_group: "admin")
  ```

  This will enable the flag globally, but disable it for users in the "admin" group.

  ## Notes

  * If `FunWithFlags` is not available at runtime (e.g., not installed), the plug assumes the flag is **enabled by default** and proceeds with normal request handling.
  * The `ExEssentials.Web.Plugs.DisableServices` struct implements the `FunWithFlags.Group` protocol to support group-based targeting.
  """

  import Plug.Conn

  require Logger

  alias ExEssentials.Web.Plugs.DisableServices
  alias FunWithFlags.Group
  alias Plug.Conn

  defstruct [:current_user]

  @behaviour Plug

  @callback get_current_user(Conn.t()) :: String.t() | nil

  @disable_services_default_flag_name :disable_services_enabled

  defmacro __using__(_opts) do
    quote do
      import Plug.Conn

      require Logger

      alias ExEssentials.Web.Plugs.DisableServices
      alias Plug.Conn

      @behaviour DisableServices

      def init(opts), do: opts

      def call(conn, opts) do
        %Conn{private: %{phoenix_action: action}, method: method, request_path: request_path} = conn
        disabled_actions = Keyword.get(opts, :disabled_actions, [])
        current_user = get_current_user(conn)
        user_info_log = if current_user, do: " Current user: #{current_user}", else: ""

        if action in disabled_actions && flag_enabled?(conn, opts) do
          Logger.warning(
            "Blocked request to #{method}: #{request_path} due to disabled action: #{action}.#{user_info_log}"
          )

          conn
          |> send_resp(:service_unavailable, "Service Unavailable")
          |> halt()
        else
          conn
        end
      end

      defp flag_enabled?(conn, opts) do
        current_user = get_current_user(conn)
        disable_service = %DisableServices{current_user: current_user}
        flag_name = Keyword.get(opts, :flag_name, :disable_services_default_flag_name)
        ensure_fun = Keyword.get(opts, :ensure_fun, &Code.ensure_loaded?/1)

        if ensure_fun.(FunWithFlags) do
          FunWithFlags.enabled?(flag_name, for: disable_service)
        else
          true
        end
      end
    end
  end

  def init(opts), do: opts

  def call(conn, opts) do
    %Conn{private: %{phoenix_action: action}, method: method, request_path: request_path} = conn
    disabled_actions = Keyword.get(opts, :disabled_actions, [])
    current_user = get_current_user(conn)
    user_info_log = if current_user, do: " Current user: #{current_user}", else: ""

    if action in disabled_actions && flag_enabled?(conn, opts) do
      Logger.warning("Blocked request to #{method}: #{request_path} due to disabled action: #{action}.#{user_info_log}")

      conn
      |> send_resp(:service_unavailable, "Service Unavailable")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Extracts the current user identifier from the connection for use in group-based flag evaluation.

  This function looks first in `conn.assigns[:user_name]`, and if not found, in `conn.params["user_name"]`.

  ## Examples

      iex> conn = %Plug.Conn{assigns: %{user_name: "admin"}}
      iex> ExEssentials.Web.Plugs.DisableServices.get_current_user(conn)
      "admin"

      iex> conn = %Plug.Conn{params: %{"user_name" => "admin"}}
      iex> ExEssentials.Web.Plugs.DisableServices.get_current_user(conn)
      "admin"

      iex> ExEssentials.Web.Plugs.DisableServices.get_current_user(%Plug.Conn{})
      nil
  """
  def get_current_user(%Conn{assigns: %{user_name: user_name}}), do: user_name
  def get_current_user(%Conn{params: params}) when is_map(params), do: Map.get(params, "user_name")
  def get_current_user(_), do: nil

  defp flag_enabled?(conn, opts) do
    current_user = get_current_user(conn)
    disable_service = %DisableServices{current_user: current_user}
    flag_name = Keyword.get(opts, :flag_name, @disable_services_default_flag_name)
    ensure_fun = Keyword.get(opts, :ensure_fun, &Code.ensure_loaded?/1)

    if ensure_fun.(FunWithFlags) do
      FunWithFlags.enabled?(flag_name, for: disable_service)
    else
      true
    end
  end

  defimpl Group, for: DisableServices do
    def in?(%{current_user: current_user}, group_name) when is_binary(current_user),
      do: current_user == group_name

    def in?(_, _), do: false
  end
end
