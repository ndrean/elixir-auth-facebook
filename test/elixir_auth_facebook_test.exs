defmodule ElixirAuthFacebookTest do
  use ExUnit.Case, async: true

  test "raising on missing env" do
    env_app_id = System.get_env("FACEBOOK_APP_ID")
    env_app_secret = System.get_env("FACEBOOK_APP_SECRET")
    env_app_state = System.get_env("FACEBOOK_STATE")

    if env_app_id == nil,
      do: assert_raise(RuntimeError, "App ID missing", fn -> raise "App ID missing" end)

    if env_app_secret == nil,
      do: assert_raise(RuntimeError, "App secret missing", fn -> raise "App secret missing" end)

    if env_app_state == nil,
      do: assert_raise(RuntimeError, "App state missing", fn -> raise "App state missing" end)
  end

  test "credentials & config" do
    env_app_id = System.get_env("FACEBOOK_APP_ID")
    config_app_id = Application.get_env(:elixir_auth_facebook, :app_id)

    env_app_secret = System.get_env("FACEBOOK_APP_SECRET")
    config_app_secret = Application.get_env(:elixir_auth_facebook, :app_secret)

    if env_app_id != nil do
      assert(env_app_id == config_app_id)
      assert env_app_id == ElixirAuthFacebook.app_id()
    end

    if env_app_secret != nil do
      assert env_app_secret == config_app_secret
      assert env_app_secret == ElixirAuthFacebook.app_secret()
    end
  end

  test "redirect_urls" do
    conn = %{host: "dwyl.com"}

    assert ElixirAuthFacebook.get_baseurl_from_conn(conn) ==
             "https://dwyl.com"

    conn = %{host: "localhost", port: 4000}

    assert ElixirAuthFacebook.get_baseurl_from_conn(conn) ==
             "http://localhost:4000"

    callback_url = "/auth/facebook/callback"
    fb_dialog_oauth = "https://www.facebook.com/v15.0/dialog/oauth?"

    assert ElixirAuthFacebook.generate_redirect_url(conn) ==
             "http://localhost:4000" <> callback_url

    conn = %{host: "dwyl.com"}

    assert ElixirAuthFacebook.generate_redirect_url(conn) ==
             "https://dwyl.com" <> callback_url

    conn = %{host: "localhost", port: 4000}

    assert ElixirAuthFacebook.generate_oauth_url(conn) ==
             fb_dialog_oauth <> ElixirAuthFacebook.params_1(conn)

    fb_access_token = "https://graph.facebook.com/v15.0/oauth/access_token?"

    assert ElixirAuthFacebook.access_token_uri("123", conn) ==
             fb_access_token <>
               "client_id=1234&client_secret=ABCD&code=123&redirect_uri=http%3A%2F%2Flocalhost%3A4000%2Fauth%2Ffacebook%2Fcallback"

    fb_profile = "https://graph.facebook.com/v15.0/me?fields=id,email,name,picture"

    assert ElixirAuthFacebook.graph_api("access") ==
             fb_profile <> "&" <> "access"
  end

  test "state" do
    env_app_state = System.get_env("FACEBOOK_STATE")
    config_app_state = Application.get_env(:elixir_auth_facebook, :app_state)

    if env_app_state != nil do
      assert env_app_state == config_app_state

      assert ElixirAuthFacebook.get_state() == config_app_state
      assert ElixirAuthFacebook.check_state(config_app_state) == true

      state = "123"
      assert ElixirAuthFacebook.check_state(state) == false
    end
  end

  test "build params HTTPS" do
    conn = %{host: "dwyl.com"}
    url = "https%3A%2F%2Fdwyl.com%2Fauth%2Ffacebook%2Fcallback"
    expected = "client_id=1234&redirect_uri=#{url}&scope=public_profile&state=1234"
    assert ElixirAuthFacebook.params_1(conn) == expected

    expected = "client_id=1234&client_secret=ABCD&code=code&redirect_uri=#{url}"
    assert ElixirAuthFacebook.params_2("code", conn) == expected
  end

  test "build params HTTP" do
    conn = %Plug.Conn{host: "localhost", port: 4000}
    url = "http%3A%2F%2Flocalhost%3A4000%2Fauth%2Ffacebook%2Fcallback"
    expected = "client_id=1234&redirect_uri=#{url}&scope=public_profile&state=1234"
    assert ElixirAuthFacebook.params_1(conn) == expected

    expected = "client_id=1234&client_secret=ABCD&code=code&redirect_uri=#{url}"
    assert ElixirAuthFacebook.params_2("code", conn) == expected
  end

  test "exchange_id" do
    profile = %{id: 1}
    assert ElixirAuthFacebook.exchange_id(profile) == %{fb_id: 1}
  end

  test "check_profile" do
    profile = %{"a" => 1, "b" => 2, "id" => 12, "picture" => %{"data" => %{"url" => 3}}}
    expected = %{a: 1, b: 2, id: 12, picture: %{"data" => %{"url" => 3}}}
    assert ElixirAuthFacebook.into_atoms(profile) == expected

    expected = %{a: 1, b: 2, id: 12, picture: %{url: 3}}
    assert ElixirAuthFacebook.nice_map(profile) == expected

    conn = %Plug.Conn{
      assigns: %{access_token: "token", profile: profile}
    }

    res = %{a: 1, b: 2, fb_id: 12, picture: %{url: 3}}
    assert ElixirAuthFacebook.check_profile(conn) == {:ok, res}
  end

  test "captures errors" do
    assert ElixirAuthFacebook.check_profile({:error, "test"}) ==
             {:error, {:check_profile, "test"}}

    assert ElixirAuthFacebook.get_profile(%Plug.Conn{
             host: "localhost",
             port: 4000,
             assigns: %{data: %{"error" => %{"message" => "renew your credentials"}}}
           }) ==
             {:error, {:get_profile, "renew your credentials"}}
  end

  test "errors" do
    conn = %Plug.Conn{host: "localhost", port: 4000}

    assert ElixirAuthFacebook.handle_callback(conn, %{"state" => "1234", "code" => "bad"}) ==
             {:error, {:check_profile, {:get_profile, "Invalid verification code format."}}}

    conn = %Plug.Conn{host: "localhost", port: 4000, assigns: %{data: %{"access_token" => "A"}}}

    assert ElixirAuthFacebook.handle_callback(conn, %{"state" => "1234", "code" => "bad_at"}) ==
             {:error, {:check_profile2, "bad profile"}}
  end

  test "handle user positive" do
    conn = %Plug.Conn{host: "localhost", port: 4000}

    assert ElixirAuthFacebook.handle_callback(conn, %{"state" => "1234", "code" => "code"}) ==
             {:ok,
              %{
                access_token: "AT",
                email: "harry@potter.com",
                fb_id: "10228683763268904",
                is_valid: true,
                name: "Harry Potter",
                picture: %{
                  height: "50",
                  is_silhouette: "false",
                  url: "www.dwyl.com",
                  width: "50"
                }
              }}
  end

  test "handle user deny dialog" do
    assert ElixirAuthFacebook.handle_callback(%Plug.Conn{}, %{"error" => "ok"}) ==
             {:error, {:access, "ok"}}
  end

  test "handle error state" do
    assert ElixirAuthFacebook.handle_callback(%Plug.Conn{}, %{"state" => "123", "code" => "code"}) ==
             {:error, {:state, "Error with the state"}}
  end
end
