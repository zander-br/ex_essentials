defmodule ExEssentials.Web.Plugs.NormalizeQueryParamsTest do
  use ExUnit.Case

  import Plug.Test

  alias ExEssentials.Web.Plugs.NormalizeQueryParams
  alias Plug.Conn

  describe "call/2" do
    test "should return empty string when \"\" is provided" do
      conn = conn(:get, "/api/resource?empty=%22%22", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"empty" => ""} == query_params
    end

    test "should return nil when null is provided" do
      conn = conn(:get, "/api/resource?nothing=null", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"nothing" => nil} == query_params
    end

    test "should return nil when undefined is provided" do
      conn = conn(:get, "/api/resource?unset=undefined", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"unset" => nil} == query_params
    end

    test "should return 'true' and 'false' when booleans is provided" do
      conn = conn(:get, "/api/resource?flag1=true&flag2=false", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"flag1" => true, "flag2" => false} == query_params
    end

    test "should return integer when integer string is provided" do
      conn = conn(:get, "/api/resource?limit=123", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"limit" => 123} == query_params
    end

    test "should return float when numeric string is provided" do
      conn = conn(:get, "/api/resource?pi=3.14", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"pi" => 3.14} == query_params
    end

    test "should return [] when list is provided" do
      conn = conn(:get, "/api/resource?list=[]", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"list" => []} == query_params
    end

    test "should return %{} when empty map is provided" do
      conn = conn(:get, "/api/resource?map={}", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"map" => %{}} == query_params
    end

    test "should return nested map when map is provided" do
      url = "/api/resource?location={city%3A%20New%20York%2C%20country%3A%20USA%2C%20year%3A%202025}"
      conn = conn(:get, url, %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"location" => %{"city" => "New York", "country" => "USA", "year" => 2025}} == query_params
    end

    test "should return list when comma separated string is provided" do
      conn = conn(:get, "/api/resource?status=open,closed", %{})
      assert %Conn{query_params: query_params} = NormalizeQueryParams.call(conn, [])
      assert %{"status" => ["open", "closed"]} == query_params
    end
  end
end
