defmodule HTTPoisonMock do
  @moduledoc """
  Mock the HTTP calls to FB for testing
  """

  @app_id Application.compile_env(:elixir_auth_facebook, :app_id)
  @app_secret Application.compile_env(:elixir_auth_facebook, :app_secret)

  @http "http%3A%2F%2Flocalhost%3A4000%2Fauth%2Ffacebook%2Fcallback"
  @url_http_exchange "https://graph.facebook.com/v15.0/oauth/access_token?client_id=#{@app_id}&client_secret=#{@app_secret}&code=code&redirect_uri=#{@http}"

  def get!(@url_http_exchange) do
    %{
      host: "localhost",
      port: 4000,
      body: Jason.encode!(%{"access_token" => "AT"})
    }
  end

  # user profile retrieve with id and token
  @bad_profile "https://graph.facebook.com/v15.0/me?fields=id,email,name,picture&access_token=A"

  def get!(@bad_profile) do
    %{body: Jason.encode!(%{"error" => %{"message" => "bad profile"}})}
  end

  @good_profile "https://graph.facebook.com/v15.0/me?fields=id,email,name,picture&access_token=AT"

  def get!(@good_profile) do
    %{
      body:
        Jason.encode!(%{
          access_token: "AT",
          is_valid: true,
          email: "harry@potter.com",
          id: "10228683763268904",
          name: "Harry Potter",
          picture: %{
            "data" => %{
              "height" => "50",
              "is_silhouette" => "false",
              "url" => "www.dwyl.com",
              "width" => "50"
            }
          }
        })
    }
  end
end
