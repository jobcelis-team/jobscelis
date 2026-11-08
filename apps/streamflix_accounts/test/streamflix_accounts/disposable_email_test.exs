defmodule StreamflixAccounts.DisposableEmailTest do
  use ExUnit.Case, async: true

  alias StreamflixAccounts.DisposableEmail

  test "detects listed providers, case-insensitively" do
    assert DisposableEmail.disposable?("bot@fextemp.com")
    assert DisposableEmail.disposable?("bot@MAILINATOR.com")
  end

  test "detects subdomains of a listed provider" do
    assert DisposableEmail.disposable?("bot@mail.yopmail.com")
  end

  test "accepts regular providers and company domains" do
    refute DisposableEmail.disposable?("ana@gmail.com")
    refute DisposableEmail.disposable?("ana@jobcelis.com")
    refute DisposableEmail.disposable?("ana@notyopmail.com")
  end

  test "handles malformed input" do
    refute DisposableEmail.disposable?("no-at-sign")
    refute DisposableEmail.disposable?(nil)
  end
end
