# Локальный запуск Web-версии

Инструкция для ветки `web3`. Docker для локального запуска не нужен.

## Что установить

- Node.js и pnpm;
- Flutter SDK;
- PostgreSQL;
- Google Chrome.

## 1. Создайте базу данных

Создайте базу `smart_light` в локальном PostgreSQL. Например, из PowerShell:

```powershell
psql -U postgres -c "CREATE DATABASE smart_light;"
```

Если база уже существует, повторно создавать её не нужно. Если команда `psql` не найдена, создайте базу `smart_light` через pgAdmin.

## 2. Заполните backend/.env

Из корня репозитория создайте локальный файл настроек:

```powershell
Copy-Item backend/.env.example backend/.env
```

Откройте `backend/.env` и укажите параметры PostgreSQL и секреты. Минимальный пример:

```dotenv
DATABASE_URL="postgresql://postgres:ВАШ_ПАРОЛЬ@localhost:5432/smart_light"

JWT_ACCESS_SECRET="локальный-длинный-секрет-для-access"
JWT_REFRESH_SECRET="другой-локальный-длинный-секрет"
JWT_ACCESS_EXPIRES="15m"
JWT_REFRESH_EXPIRES="30d"

EMAIL_CODE_SECRET="ещё-один-длинный-локальный-секрет"
VERIFICATION_DELIVERY="console"
CORS_ALLOWED_ORIGINS="http://localhost:5000"

SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM="Smart Light <onboarding@resend.dev>"
```

Замените `ВАШ_ПАРОЛЬ` на пароль пользователя PostgreSQL. Если пароль содержит `@`, `/`, `:` или `#`, URL-кодируйте эти символы в `DATABASE_URL`. Секреты выше — примеры для локальной разработки; задайте собственные значения. Файл `backend/.env` не добавляйте в Git.

`CORS_ALLOWED_ORIGINS` должен точно совпадать с адресом Flutter Web. Если запустите приложение на другом порту, укажите здесь новый origin, например `http://localhost:5001`.

## 3. Запустите backend

Откройте терминал в корне репозитория и выполните:

```powershell
Set-Location backend
pnpm install
pnpm exec prisma generate
pnpm exec prisma migrate deploy
pnpm dev
```

Backend запустится на `http://localhost:3000`. Оставьте этот терминал открытым.

## 4. Запустите Flutter Web

Откройте второй терминал в корне репозитория:

```powershell
Set-Location smart_light
flutter pub get
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000
```

Приложение откроется на `http://localhost:5000`. Backend должен продолжать работать в первом терминале.

## Коды подтверждения в консоли

Для локальной разработки оставьте в `backend/.env`:

```dotenv
VERIFICATION_DELIVERY="console"
```

Перезапустите backend после изменения `.env`. При регистрации backend выведет в свой терминал строку вида:

```text
[email verification] user@example.com: 123456
```

Введите код на экране подтверждения e-mail. В локальном режиме приложение также показывает код на этом экране.

Для сброса пароля запросите код на экране восстановления. В терминале backend появится строка вида:

```text
[password reset] user@example.com: 654321
```

Введите его в приложении; код сброса также отображается на экране. Код действует 10 минут. Для сброса пароля адрес должен принадлежать зарегистрированному пользователю с подтверждённой почтой.

В режиме `console` письма не отправляются. SMTP-поля можно оставить пустыми. Чтобы переключиться на отправку писем, настройте SMTP и укажите `VERIFICATION_DELIVERY="email"`.

## Возможные ошибки

- Ошибка подключения к базе: проверьте, что PostgreSQL запущен, база существует, а `DATABASE_URL` содержит правильные логин и пароль.
- Ошибка CORS в браузере: проверьте `CORS_ALLOWED_ORIGINS` и перезапустите backend после изменения `.env`.
- Приложение обращается к удалённому API: убедитесь, что команда Flutter содержит `--dart-define=API_BASE_URL=http://localhost:3000`.
- Для BLE provisioning используйте Chrome и `localhost`.
