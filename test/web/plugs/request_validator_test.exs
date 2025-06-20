defmodule ExEssentials.Web.Plugs.RequestValidatorTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Plug.Conn
  import Plug.Test

  alias ExEssentials.Web.Plugs.RequestValidator
  alias Support.Validators.User, as: UserValidator

  describe "call/2" do
    setup do
      Application.delete_env(:ex_essentials, :web_request_validator)
      opts = RequestValidator.init(validator: UserValidator)

      params = %{
        "courses" => [
          %{"name" => "Elixir Types", "duration" => 30, "level" => "beginner"},
          %{"name" => "Elixir Genserver", "duration" => 60, "level" => "advanced"}
        ],
        "email" => "joe.doe@mail.com",
        "name" => "Joe Doe",
        "preferences" => %{"theme" => "dark", "language" => "en"}
      }

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

    test "should return a conn with status :bad_request when the data is invalid",
         %{opts: opts, params: params} do
      invalid_courses = [
        %{"name" => "Elixir Types", "duration" => 30, "level" => "beginner"},
        %{"name" => "Elixir Genserver", "duration" => 60, "level" => "hero"}
      ]

      invalid_preferences = %{"theme" => "bluedark"}

      invalid_params =
        params
        |> Map.delete("name")
        |> Map.put("preferences", invalid_preferences)
        |> Map.put("courses", invalid_courses)

      conn =
        conn(:post, "/api/users", invalid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert ["application/problem+json"] == get_resp_header(conn, "content-type")
      assert %{"errors" => errors, "status_code" => 400} = json_response(conn, :bad_request)

      assert [
               %{
                 "code" => "invalid_parameter",
                 "detail" => "The 'name' field can't be blank",
                 "title" => "Invalid request parameters"
               },
               %{
                 "code" => "invalid_parameter",
                 "detail" => "The 'courses.[1].level' field is invalid",
                 "title" => "Invalid request parameters"
               },
               %{
                 "code" => "invalid_parameter",
                 "detail" => "The 'preferences.language' field can't be blank",
                 "title" => "Invalid request parameters"
               },
               %{
                 "code" => "invalid_parameter",
                 "detail" => "The 'preferences.theme' field is invalid",
                 "title" => "Invalid request parameters"
               }
             ] == errors
    end

    test "should return a conn with status :bad_request when the data is invalid and a custom error_code is configured",
         %{opts: opts, params: params} do
      Application.put_env(:ex_essentials, :web_request_validator, error_code: :validation_error)

      invalid_params = Map.delete(params, "name")

      conn =
        conn(:post, "/api/users", invalid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert %{"errors" => errors, "status_code" => 400} = json_response(conn, :bad_request)

      assert [
               %{
                 "code" => "validation_error",
                 "detail" => "The 'name' field can't be blank",
                 "title" => "Invalid request parameters"
               }
             ] == errors
    end

    test "should return a conn with status :bad_request when the data is invalid and a custom error_title is configured",
         %{opts: opts, params: params} do
      Application.put_env(:ex_essentials, :web_request_validator, error_title: "Validation request error")

      invalid_params = Map.delete(params, "name")

      conn =
        conn(:post, "/api/users", invalid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert %{"errors" => errors, "status_code" => 400} = json_response(conn, :bad_request)

      assert [
               %{
                 "code" => "invalid_parameter",
                 "detail" => "The 'name' field can't be blank",
                 "title" => "Validation request error"
               }
             ] == errors
    end
  end
end
