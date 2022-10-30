defmodule MyAppWeb.FacebookSdkAuthController do
  use MyAppWeb, :controller

  action_fallback(MyAppWeb.LoginError)

  # below is an example of handling the obtained "profile"
  # you save to the database and put the data in the session
  # ( I used a Repo.insert with an "on_conflict" and "conflict_target" clause
  # instead of a find_or_create...)
  def handle(conn, params) do
    with profile <- ElixirSdkFacebookHelper,
         %{email: email} <- profile do
      # you want to pass the name or email and ID
      user = MyApp.User.new(email)
      user_token = MyApp.Token.user_generate(user.id)

      conn
      |> fetch_session()
      |> put_session(:user_token, user_token)
      |> put_session(:user_id, user.id)
      |> put_session(:origin, "fb_sdk")
      |> put_session(:profile, profile)
      |> put_view(MyAppWeb.WelcomeView)
      |> redirect(to: "/welcome")
      |> halt()
    end
  end
end
