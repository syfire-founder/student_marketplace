# Android tester backend deployment (Render)

This is the temporary test deployment plan for the 20 Android testers. It uses
Render Web Service + Render PostgreSQL. The local `db.sqlite3` remains the
untouched source while a private fixture is loaded into a new hosted database.

## Test-phase email switches

Set these two private service environment variables on Render:

- `REQUIRE_EMAIL_VERIFICATION=False`
- `EMAIL_NOTIFICATIONS_ENABLED=False`

When verification is off, registration creates the account and returns its
login token directly. Email notifications are skipped. Password recovery by
email is paused until the email provider is configured. The defaults remain
`True`, so regular email behavior can be restored by changing both variables
back to `True` after the phone test.

## Keep a local backup and export the SQLite data

Run these commands from the repository root in PowerShell. Stop the local
Django server first so no one is writing to the SQLite database while it is
being copied/exported.

```powershell
New-Item -ItemType Directory -Path .\private-test-backup -Force
Copy-Item .\db.sqlite3 .\private-test-backup\db-before-hosting.sqlite3
Copy-Item .\media .\private-test-backup\media-before-hosting -Recurse
.\venv\Scripts\python.exe manage.py dumpdata --natural-foreign --natural-primary --exclude=contenttypes --exclude=auth.permission --exclude=sessions --output=.\private-test-backup\bluubase-test-data.json
```

The JSON export contains user information and authentication tokens. Keep
`private-test-backup` on your computer, never commit it or send it in chat, and
delete it securely when the transfer and backup-retention period are complete.
The ignored folder keeps Git from including it by accident.

## Create the hosted services

1. Sign in at [Render](https://dashboard.render.com/).
2. Click **New → PostgreSQL**. Pick a paid plan if the hosted test data must
   remain available and recoverable; free PostgreSQL expires after 30 days and
   has no backups.
3. Create the database in a region near your testers. Keep its **Internal
   Database URL** private; use it only as the web service's `DATABASE_URL`.
4. Click **New → Web Service**, connect the GitHub repository
   `syfire-founder/student_marketplace`, and use the repository root as the
   service root directory.
5. Choose Python. Set:
   - Build command: `pip install -r requirements.txt && python manage.py collectstatic --noinput`
   - Pre-deploy command: `python manage.py migrate --noinput`
   - Start command: `gunicorn config.wsgi:application --bind 0.0.0.0:$PORT`
6. Add a persistent disk to the paid web service, mounted at `/var/data`. Set
   its size based on the current `media` folder size plus room for tester
   uploads. Set `MEDIA_ROOT` to `/var/data/media` in the service environment.
   Only files under `/var/data` persist across service restarts/deploys.
7. Add these service environment variables (use the dashboard's **Generate**
   action for `SECRET_KEY`):

   | Variable | Value |
   | --- | --- |
   | `SECRET_KEY` | Generate a new secret in Render; do not reuse `.env` |
   | `DEBUG` | `False` |
   | `ALLOWED_HOSTS` | The exact service hostname, e.g. `bluubase-api.onrender.com` |
   | `DATABASE_URL` | The database's Internal Database URL |
   | `MEDIA_ROOT` | `/var/data/media` |
   | `EMAIL_NOTIFICATIONS_ENABLED` | `False` |
   | `REQUIRE_EMAIL_VERIFICATION` | `False` |
   | `SECURE_SSL_REDIRECT` | `True` |
   | `TRUST_PROXY_SSL_HEADER` | `True` |
   | `SECURE_HSTS_SECONDS` | `0` for the initial test |

   Leave `CORS_ALLOWED_ORIGINS` empty for the native Android app. Do not set
   `DEBUG=True`, `ALLOWED_HOSTS=*`, or put any secret in GitHub.
8. Deploy the service and wait for it to become **Live**. Note the HTTPS
   hostname, for example `https://bluubase-api.onrender.com`.

## Import the data without replacing the source database

1. Before making the API available to testers, open the web service's **Shell**
   in Render. Run `python manage.py migrate --noinput` there once more if the
   pre-deploy step did not run successfully.
2. Set up SSH for the paid web service using Render's **Connect → SSH** steps.
   Use the SSH host and username shown for your service. Upload the JSON fixture
   into the running service, for example:

   ```powershell
   scp -s .\private-test-backup\bluubase-test-data.json SERVICE_USER@ssh.REGION.render.com:/var/data/bluubase-test-data.json
   ```

   Replace the example filename if needed so it exactly matches the export
   created above. Do not paste the connection string or fixture contents in
   chat.
3. In the Render service Shell, run:

   ```sh
   python manage.py loaddata /var/data/bluubase-test-data.json
   ```

   Run this only once against the new empty hosted database. It imports records;
   it does not copy media files.
4. Copy local uploads to the persistent disk with SCP. Render's SSH/SCP
   connection details are shown under **Connect → SSH**. Copy the contents of
   local `media` into remote `/var/data/media`, keeping the directory structure:

   ```powershell
   scp -r -s .\media SERVICE_USER@ssh.REGION.render.com:/var/data/
   ```

   The remote destination `/var/data/` is the disk mount, so this creates
   `/var/data/media`. Replace the SSH username and region with the values shown
   in Render.
5. Compare the local and hosted user/listing counts in Django admin. Keep the
   original `db.sqlite3` and `media` backup unchanged until this check succeeds.

## Point the tester APK at the hosted API

In `swix_app`, build with the real HTTPS API URL:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://bluubase-api.onrender.com/api
```

Replace the example hostname with the actual Render hostname. This build-time
setting changes the endpoint in the app package; Android emulators keep using
the local default during development. Install the APK on one phone first and
check registration, login, listing images, and messages before inviting the
other testers.

## Backups and rollback

- Keep the original SQLite database and media backup locally and unchanged.
- Take a Render PostgreSQL export before large changes. Paid Postgres plans
  also include point-in-time recovery; free Postgres does not.
- If the hosted import is wrong, stop before inviting testers. Create a fresh
  empty Postgres database and repeat the import from the local export; do not
  overwrite the original SQLite database.
- To restore email later, configure and verify the email provider first, then
  set both email switches to `True` and redeploy. Registration will again
  require the email code.
