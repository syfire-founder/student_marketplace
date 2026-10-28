# BluuBase backend release preparation

The Django project is prepared for a Linux WSGI host, but it is not deployed.
Choose a hosting provider and configure its environment variables before
starting the public service.

## Production environment

Set these values in the hosting provider's private environment settings:

- `SECRET_KEY`: a new, long, random production-only secret. Do not reuse the
  local development key.
- `DEBUG=False`
- `ALLOWED_HOSTS`: comma-separated hostnames only, such as the provider host
  and BluuBase API domain. Do not use `*`.
- `DATABASE_URL`: a managed PostgreSQL connection URL. Production settings
  reject SQLite so the app cannot silently use an ephemeral local database.
- `SECURE_SSL_REDIRECT=True`
- `TRUST_PROXY_SSL_HEADER=True` only if the hosting provider terminates HTTPS
  and sets a sanitized `X-Forwarded-Proto` header.
- `CSRF_TRUSTED_ORIGINS`: full HTTPS origins for any browser-based admin or
  frontend.
- `CORS_ALLOWED_ORIGINS`: full HTTPS origins only if BluuBase serves a browser
  frontend. Native Android and iOS apps do not use browser CORS.
- `SECURE_HSTS_SECONDS`: enable after HTTPS is confirmed on the final domain;
  start with a short value and increase it after verification.
- Only enable HSTS for subdomains or request browser preload after confirming
  every affected hostname will stay HTTPS-only. Django's deploy check warns
  about these optional settings until that domain-wide decision is made.
- `MEDIA_ROOT`: a persistent disk path only if the host provides durable
  storage. Otherwise configure an object-storage backend before accepting
  uploads.

The API requires email codes for registration and account recovery. Production
startup intentionally fails until a real email backend and sender are
configured. SendGrid setup remains pending; the sample settings are in
`.env.example`.

## Build and run commands

- Install dependencies: `python -m pip install -r requirements.txt`
- Collect Django admin static files: `python manage.py collectstatic --noinput`
- Apply schema changes as a pre-deploy/release command:
  `python manage.py migrate --noinput`
- Start the web process with the included `Procfile`.
- Before launch, run `python manage.py check --deploy` against the production
  environment and resolve every warning that applies to the chosen host.

Create the first administrator account through a controlled one-off host
command after migrations. Do not enable public registration as a staff user.

## Remaining launch decisions

- Select the application host and configure its hostname and TLS.
- Provision PostgreSQL and configure backups.
- Choose durable storage for business logos and listing photos; the current
  default media directory is local development storage.
- Complete the email provider and verified sender setup.
- Set up production error reporting and log retention.
