defmodule ExEssentials.Web.Plugs.DisableServicesTest do
  use ExEssentials.DataCase

  import Plug.Conn
  import Plug.Test

  alias ExEssentials.Web.Plugs.DisableServices

  defmodule CustomDisableServices do
    use ExEssentials.Web.Plugs.DisableServices

    alias Plug.Conn

    @impl true
    def get_current_user(%Conn{params: params}), do: Map.get(params, "realm")
    def get_current_user(_), do: nil
  end

  describe "call/2" do
    setup do
      opts = DisableServices.init(disabled_actions: [:create, :delete], flag_name: :services_disabled)
      FunWithFlags.clear(:services_disabled)
      FunWithFlags.clear(:disable_services_enabled)
      %{opts: opts}
    end

    test "should return a conn with state :unset when the flag is active but disabled for the provided user_name group",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)
      FunWithFlags.disable(:services_disabled, for_group: "joe.doe")

      conn =
        conn(:post, "/api/resource", %{})
        |> Map.put(:assigns, %{user_name: "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with state :unset when the flag is active but disabled for the provided user_name",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)
      FunWithFlags.disable(:services_disabled, for_group: "joe.doe")

      conn =
        conn(:post, "/api/resource", %{"user_name" => "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with status :service_unavailable when the flag is globally enabled and enabled for the user_name group",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)
      FunWithFlags.enable(:services_disabled, for_group: "joe.doe")

      conn =
        conn(:post, "/api/resource", %{})
        |> Map.put(:assigns, %{user_name: "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with status :service_unavailable when the flag is globally enabled and enabled for provided user_name",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)
      FunWithFlags.enable(:services_disabled, for_group: "joe.doe")

      conn =
        conn(:post, "/api/resource", %{"user_name" => "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with status :service_unavailable when the flag is disabled globally but enabled for the user_name group",
         %{opts: opts} do
      FunWithFlags.disable(:services_disabled)
      FunWithFlags.enable(:services_disabled, for_group: "joe.doe")

      conn =
        conn(:post, "/api/resource", %{})
        |> Map.put(:assigns, %{user_name: "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with status :service_unavailable when the flag is disabled globally but enabled for provided user_name",
         %{opts: opts} do
      FunWithFlags.disable(:services_disabled)
      FunWithFlags.enable(:services_disabled, for_group: "joe.doe")

      conn =
        conn(:post, "/api/resource", %{"user_name" => "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with status :service_unavailable when the action is configured as disabled and the flag is enabled",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)

      conn =
        conn(:post, "/api/resource", %{})
        |> Map.put(:assigns, %{user_name: "joe.doe"})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with status :service_unavailable when the action is disabled and the default flag is enabled" do
      opts = DisableServices.init(disabled_actions: [:create, :delete])
      FunWithFlags.enable(:disable_services_enabled)

      conn =
        conn(:post, "/api/resource", %{})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with state :unset when the action is not in the disabled list",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)

      conn =
        conn(:get, "/api/resource", %{})
        |> put_private(:phoenix_action, :show)
        |> DisableServices.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with state :unset when the feature flag is disabled",
         %{opts: opts} do
      FunWithFlags.disable(:services_disabled)

      conn =
        conn(:post, "/api/resource", %{})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with state :unset when the default flag is disabled" do
      opts = DisableServices.init(disabled_actions: [:create, :delete])
      FunWithFlags.disable(:disable_services_enabled)

      conn =
        conn(:post, "/api/resource", %{})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with state :unset when flag not defined",
         %{opts: opts} do
      conn =
        conn(:post, "/api/resource", %{})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with status :service_unavailable when FunWithFlags is not loaded and action is disabled" do
      opts = DisableServices.init(disabled_actions: [:create, :delete], ensure_fun: fn _module -> false end)

      conn =
        conn(:post, "/api/resource", %{})
        |> put_private(:phoenix_action, :create)
        |> DisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end

    test "should return a conn with status :service_unavailable when using custom plug and realm is flagged",
         %{opts: opts} do
      FunWithFlags.enable(:services_disabled)
      FunWithFlags.enable(:services_disabled, for_group: "ex_essentials")

      conn =
        conn(:post, "/api/resource", %{"realm" => "ex_essentials"})
        |> put_private(:phoenix_action, :create)
        |> CustomDisableServices.call(opts)

      assert conn.status == 503
      assert conn.resp_body == "Service Unavailable"
    end
  end
end
