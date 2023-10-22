defmodule WavenetForChromeWeb.Router do
  use WavenetForChromeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WavenetForChromeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WavenetForChromeWeb do
    pipe_through :api

    get "/", RootController, :index
  end

  scope "/v1", WavenetForChromeWeb do
    pipe_through :api

    get "/", RootController, :index
    get "/health", HealthController, :index
    post "/synthesize", TextToSpeechController, :synthesize
    resources "/users", UserController
    resources "/insights", InsightController
    resources "/voices", VoiceController
    resources "/payment-sessions", PaymentSessionController
    resources "/invoices", InvoiceController
    resources "/stripe-webhooks", StripeWebhookController
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wavenet_for_chrome, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WavenetForChromeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
