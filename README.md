# ExEssentials

<p align="center">
  <picture>
    <source srcset="https://raw.githubusercontent.com/zander-br/ex_essentials/main/assets/ex_essentials.png">
    <img alt="ExEssentials logo" src="https://raw.githubusercontent.com/zander-br/ex_essentials/main/assets/ex_essentials.png" width="320">
  </picture>
</p>

<p align="center">
  <a href="https://hex.pm/packages/ex_essentials"><img src="https://img.shields.io/hexpm/v/ex_essentials.svg" alt="Hex version"></a>
  <a href="https://hexdocs.pm/ex_essentials"><img src="https://img.shields.io/badge/hex-docs-lightgrey.svg" alt="Hex docs"></a>
  <a href="https://github.com/zander-br/ex_essentials/blob/main/LICENSE.txt"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="License"></a>
</p>

**ExEssentials** is a powerful utility library for Elixir that serves as a true toolbox — bringing together a collection of generic, reusable, and ready-to-use helpers to accelerate Elixir application development.

Designed with a focus on productivity and organization, it helps you write cleaner, more maintainable code while saving valuable development time.

---

## Features

- 🛠 **Flow Builder (Runner)**: Model complex business logic as a sequence of named steps (sync or async) with built-in error recovery.
- 🇧🇷 **Brazilian Document Validation**: Robust CPF and CNPJ (numeric & alphanumeric) validation and formatting.
- 🌐 **Web & API Helpers**: RFC 7807 compliant request validation, query parameter normalization, and service toggling.
- 📑 **XML Utilities**: Safe and sanitized XML building built on top of Saxy.
- 🗺 **Map Utilities**: Clean way to rename keys, compact `nil`, or blank values from maps.

---

## Installation

The package can be installed by adding `ex_essentials` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_essentials, "~> 0.10.1"}
  ]
end
```

---

## Usage

### 🚀 Core Runner (Flow Builder)

Inspired by `Ecto.Multi`, the `Runner` allows you to build fail-fast execution flows with named steps.

```elixir
alias ExEssentials.Core.Runner

runner =
  Runner.new(timeout: 5_000)
  |> Runner.put(:user_id, 123)
  |> Runner.run(:fetch_user, fn %{user_id: id} -> {:ok, %{id: id, name: "John"}} end)
  |> Runner.run_async(:send_email, fn _ -> {:ok, :sent} end)
  |> Runner.run(:log_action, fn %{fetch_user: user} -> {:ok, "Logged #{user.name}"} end)

case Runner.finish(runner) do
  {:ok, changes} ->
    IO.puts("User fetched: #{changes.fetch_user.name}")
  {:error, step, reason, changes_before} ->
    IO.inspect({step, reason}, label: "Flow failed")
end
```

### 🇧🇷 Brazilian Document Validation

Validate, format, and mask CPF and CNPJ numbers effortlessly. Supports alphanumeric CNPJs and automatic digit extraction.

#### Validation & Formatting

```elixir
alias ExEssentials.BrazilianDocument.Validator
alias ExEssentials.BrazilianDocument.Formatter

# Validate CPF or CNPJ (Numeric or Alphanumeric)
Validator.valid?("123.456.789-00") # => true
Validator.valid?("12ABC34501DE35") # => true (New Alphanumeric CNPJ)

# Format for display
Formatter.format("39053344705")      # => "390.533.447-05"
Formatter.format("11222333000181")   # => "11.222.333/0001-81"

# Mask sensitive data
Formatter.mask("44286185060")        # => "***.861.850-**"
Formatter.mask("20495056000171")     # => "20.***.***/0001-7*"
```

#### Ecto Integration

Easily validate documents in your changesets.

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset
  import ExEssentials.BrazilianDocument.Changeset

  schema "users" do
    field :document, :string
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:document])
    |> validate_brazilian_document(:document) # Validates CPF or CNPJ
    # Or specifically:
    # |> validate_cpf(:document)
    # |> validate_cnpj(:document)
  end
end
```

### 🛡 Web Utilities (Plugs & Validators)

#### Request Validation

A `Plug` for validating request parameters using `Ecto.Changeset`. If validation fails, it returns a `400 Bad Request` following [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807).

```elixir
# 1. Define your validator (mapping actions to changesets)
defmodule MyAppWeb.Validators.User do
  import Ecto.Changeset

  def create(params) do
    {%{}, %{name: :string, email: :string}}
    |> cast(params, [:name, :email])
    |> validate_required([:name, :email])
  end
end

# 2. Use the plug in your controller
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  plug ExEssentials.Web.Plugs.RequestValidator, validator: MyAppWeb.Validators.User

  def create(conn, params) do
    # Only executes if params are valid
    text(conn, "User Created")
  end
end
```

#### Query Parameter Normalization

Automatically converts query string values (like `"true"`, `"null"`, `"123"`, or lists `"1,2,3"`) into their Elixir types.

```elixir
# In your endpoint.ex or router pipeline
plug ExEssentials.Web.Plugs.NormalizeQueryParams

# Input:  /api/search?active=true&tags=elixir,rust&limit=10
# Output: %{"active" => true, "tags" => ["elixir", "rust"], "limit" => 10}
```

#### Feature Flag Route Disabling

Disable specific controller actions based on feature flags (supports `FunWithFlags`).

```elixir
# In your controller
plug ExEssentials.Web.Plugs.DisableServices,
  disabled_actions: [:delete, :update],
  flag_name: :maintenance_mode
```

### 📑 XML Utilities

A safe wrapper around `Saxy` to build XML documents with automatic sanitization.

```elixir
import ExEssentials.XML

# Automatically escapes <, >, &, etc.
element_sanitize("note", [], ["Some <script> & unsafe content"])
# => {"note", [], ["Some &lt;script&gt; &amp; unsafe content"]}
```

### 🗺 Map Utilities

Helpers for transforming and cleaning up map structures.

```elixir
alias ExEssentials.Core.Map, as: MapUtil

# Renaming keys
map = %{name: "Alice", age: 30}
MapUtil.renake(map, [:name, age: :years]) 
# => %{name: "Alice", years: 30}

# Cleaning up maps (removing nil or blank values)
MapUtil.compact(%{a: 1, b: nil, c: "", d: [], e: %{}}) 
# => %{a: 1}
```

---

## Configuration

You can customize the `RequestValidator` response format:

```elixir
config :ex_essentials, :web_request_validator,
  json_library: Jason,
  error_code: :invalid_parameter,
  error_title: "Invalid request parameters"
```

---

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

---

## License

ExEssentials is released under the **Apache License 2.0**. See the [LICENSE.txt](LICENSE.txt) file for details.

