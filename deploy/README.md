# Server deployment

The landing page is served at `/` and `/about.html`; the Flutter web app is served at `/app/`. Both the single host and split frontend/backend hosts are supported. Caddy obtains and renews HTTPS certificates for the configured domains.

## Frontend and backend on separate hosts

Use a frontend domain such as `app.example.com` and a backend domain such as `api.example.com`. Point each domain's DNS records to its respective server, and allow inbound TCP ports 80 and 443 on both servers (UDP 443 is optional for HTTP/3). Install Docker Engine with the Docker Compose plugin. On each server, clone this repository and check out the deployment branch:

```sh
git clone https://github.com/hineoni/smart-light-gpo.git
cd smart-light-gpo
git switch web3+deploy
```

On the backend server, copy `.env.backend.example` to `.env.backend` and `backend/.env.example` to `backend/.env`. Set `API_DOMAIN`, set `CORS_ALLOWED_ORIGINS` to the exact frontend origin (for example `https://app.example.com`), and set a hex-only PostgreSQL password so it remains safe in the connection URL. In `backend/.env`, set separate strong values for `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, and `EMAIL_CODE_SECRET`; configure SMTP values if email verification is enabled. Keep both environment files private and out of Git. Compose overrides `DATABASE_URL` with the PostgreSQL container address. Start the backend and database:

```sh
docker compose --env-file .env.backend -f docker-compose.backend.yml up --build -d
```

On the frontend server, copy `.env.frontend.example` to `.env.frontend`. Set `FRONTEND_DOMAIN` and `API_BASE_URL` to the public domains. Build and start the web app:

```sh
docker compose --env-file .env.frontend -f docker-compose.frontend.yml up --build -d
```

The Flutter web app sends HTTP requests and its WebSocket connection to `API_BASE_URL`. The backend allows browser requests only from the origins listed in `CORS_ALLOWED_ORIGINS`.

The browser URLs are separate for the main screens: `/app/login`, `/app/register`, `/app/devices`, `/app/positioning`, `/app/settings`, and `/app/device/{deviceId}`. These routes support direct opening and refresh; the app shell handles navigation without reloading the whole site.

## Prepare the server

1. Point the domain's A/AAAA records at the server and allow inbound TCP ports 80 and 443 (UDP 443 is optional for HTTP/3).
2. Install Docker Engine with the Docker Compose plugin and clone this repository.
3. Copy `.env.production.example` to `.env`. Set `DOMAIN` and `API_BASE_URL` to the public origin, and replace all passwords, JWT secrets, email secrets, and SMTP placeholders. Generate separate random values for each secret (for example, `openssl rand -hex 32`); the PostgreSQL password should use hex characters so it is safe in the connection URL.
4. Start the stack from the repository root:

   ```sh
   docker compose up --build -d
   ```

The backend applies committed Prisma migrations before serving requests. PostgreSQL data and Caddy certificates persist in named Docker volumes. Keep `.env` on the server only and back up the `postgres_data` volume.

## Updating

Pull the desired Git revision and run `docker compose up --build -d` again. Check service status and logs with `docker compose ps` and `docker compose logs -f backend web proxy`.

The Flutter web bundle is compiled with `API_BASE_URL`, so changing that value requires rebuilding the `web` service. If the domain changes, update the matching frontend and backend settings and redeploy both services.

## REG.RU virtual hosting

The ready-to-upload archive is built at `smart_light/build/web/smart-light-reg-ru-upload.zip`. It contains the landing page at the site root, the Flutter bundle under `app/`, and `.htaccess` rules for direct app links. In REG.RU's hosting panel, open **Sites → Files of site** for the chosen domain, upload the ZIP, and extract it directly into that domain's document root. The exact root directory is shown by the panel. Enable HTTPS for the domain before publishing the link.

To rebuild the archive after a frontend change, run the Flutter Web build with the actual backend URL and prepare the same layout: copy `about.html` as the root `index.html`, copy `about.html` and `about-assets/` into the root, copy the remaining web build output into `app/`, and place `deploy/reg-ru.htaccess` in the root as `.htaccess`.
