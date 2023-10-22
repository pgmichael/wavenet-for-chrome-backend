# Wavenet for Chrome backend

Backend for the [Wavenet for Chrome](https://www.github.com/pgmichael/wavenet-for-chrome) extension.

## Development

A live version of the backend is hosted at [https://api.wavenet-for-chrome.com](https://api.wavenet-for-chrome.com/v1). So running the backend locally is not required for development of the extension. However, if you want to run the backend locally, follow the instructions below:

Create a `.env` file in the root directory with the following contents:

```bash
# Google
export TTS_API_KEY=<your_api_key>
export TTS_API_URL=https://texttospeech.googleapis.com/v1

# Database
export PGHOST=<your_postgres_host>
export POSTGRES_DB=<your_postgres_db>
export POSTGRES_PASSWORD=<your_postgres_password>
export POSTGRES_USER=<your_postgres_user>

# Stripe (Not required for development using your own API key)
export STRIPE_SECRET_KEY=<your_stripe_secret_key>
export STRIPE_SIGNING_SECRET=<your_stripe_signing_secret>
export STRIPE_PRICE_ID=<your_stripe_price_id>
```

Then source your `.env` file and run the server:

```bash
# Source your .env file
source .env

# Install dependencies
mix deps.get

# Create and migrate your database
mix ecto.setup

# Run the server
mix phx.server
```
