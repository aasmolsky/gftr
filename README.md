# Gftr - Query Service

A simple Rails web application that allows users to submit queries through a form, which are then sent to an external service, and the responses are displayed and saved to the database.

## Setup

### Prerequisites
- Ruby 3.x
- PostgreSQL
- Node.js (for asset compilation)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Create `.env` file with the following variables:
   ```
   GOOGLE_CLIENT_ID=your_google_client_id
   GOOGLE_CLIENT_SECRET=your_google_client_secret
   SERP_API_KEY=your_serp_api_key
   EXTERNAL_SERVICE_URL=https://your-external-service.com/api
   ALLOWED_OMNIAUTH_HOST=localhost:3000
   ```

4. Create and migrate the database:
   ```bash
   rails db:create
   rails db:migrate
   ```

5. Start the server:
   ```bash
   rails server
   ```

Visit `http://localhost:3000` and log in with Google OAuth.

## Features

- Google OAuth authentication
- Submit queries to an external service
- View recent requests and responses
- Persistent storage of queries and responses in PostgreSQL
