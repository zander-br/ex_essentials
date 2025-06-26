defmodule ExEssentials.XML do
  @moduledoc """
  Utility module that wraps and extends `Saxy.XML` to provide a convenient and safe interface
  for building XML documents.

  This module reexports key functions from `Saxy.XML` such as `element/3`, `empty_element/2`, `characters/1`,
  and others, so you can `import ExEssentials.XML` and use them directly.

  It also provides `element_sanitize/3`, a drop-in replacement for `element/3` that automatically escapes
  special characters in text nodes to ensure well-formed XML output.

  Example:

      import ExEssentials.XML

      element_sanitize("Example", [], ["Some & unsafe < XML > text"])

  """

  alias Saxy.XML, as: SaxyXML

  @spec empty_element(name :: term(), attributes :: [{key :: term(), value :: term()}]) :: SaxyXML.element()
  defdelegate empty_element(name, attrs), to: SaxyXML

  @spec element(name :: term(), attributes :: [{key :: term(), value :: term()}], children :: term()) ::
          SaxyXML.element()
  defdelegate element(name, attrs, children), to: SaxyXML

  @spec characters(text :: term()) :: SaxyXML.characters()
  defdelegate characters(content), to: SaxyXML

  @spec cdata(text :: term()) :: SaxyXML.cdata()
  defdelegate cdata(content), to: SaxyXML

  @spec comment(text :: term()) :: SaxyXML.comment()
  defdelegate comment(content), to: SaxyXML

  @spec reference(character_type :: :entity | :hexadecimal | :decimal, value :: term()) :: SaxyXML.ref()
  defdelegate reference(character_type, value), to: SaxyXML

  @spec processing_instruction(name :: String.t(), instruction :: String.t()) :: SaxyXML.processing_instruction()
  defdelegate processing_instruction(name, instruction), to: SaxyXML

  @spec element_sanitize(term(), [{term(), term()}], term()) :: SaxyXML.element()
  def element_sanitize(name, attrs, children) do
    sanitized_children = sanitize_children(children)
    SaxyXML.element(name, attrs, sanitized_children)
  end

  defp sanitize_children(children) when is_list(children), do: Enum.map(children, &sanitize_node/1)
  defp sanitize_children(other), do: sanitize_node(other)

  defp sanitize_node({tag, attrs, children}), do: {tag, attrs, sanitize_children(children)}
  defp sanitize_node([{key, value}]) when is_atom(key) and is_binary(value), do: [{key, sanitize_text(value)}]
  defp sanitize_node([text]) when is_binary(text), do: [sanitize_text(text)]
  defp sanitize_node(text) when is_binary(text), do: sanitize_text(text)
  defp sanitize_node(other), do: other

  defp sanitize_text(value) when is_binary(value) do
    value
    |> unsanitize_text()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp unsanitize_text(value) when is_binary(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
  end
end
