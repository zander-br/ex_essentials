defmodule ExEssentials.XMLTest do
  use ExUnit.Case
  import ExEssentials.XML

  describe "empty_element/2 and element/3" do
    test "creates an empty element correctly" do
      assert {"Test", [], []} == empty_element("Test", [])
    end

    test "creates a standard element with children" do
      assert {"Test", [], ["value"]} == element("Test", [], ["value"])
    end
  end

  describe "element_sanitize/3" do
    test "should return a sanitized XML element when text includes unsafe characters" do
      assert {"Tag", [], [text]} = element_sanitize("Tag", [], ["<unsafe> & \"quoted\""])
      assert text == "&lt;unsafe&gt; &amp; &quot;quoted&quot;"
    end

    test "should return a sanitized XML element when children include nested tuples with text" do
      assert tree = element_sanitize("Root", [], [{"Child", [], ["a & b"]}, {"Other", [], [{"Inner", [], ["<tag>"]}]}])
      assert {"Root", [], [{"Child", [], ["a &amp; b"]}, {"Other", [], [{"Inner", [], ["&lt;tag&gt;"]}]}]} == tree
    end

    test "should return a sanitized XML element when children include character tuples" do
      assert tree = element_sanitize("Account", [], [[characters: "850&000"]])
      assert {"Account", [], [characters: "850&amp;000"]} == tree
    end

    test "should return a sanitized XML element when input is already sanitized" do
      assert tree = element_sanitize("X", [], ["&lt;already&gt;"])
      assert {"X", [], ["&lt;already&gt;"]} == tree
    end
  end
end
