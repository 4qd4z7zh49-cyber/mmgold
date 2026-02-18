# mmgold

Myanmar Gold Calculator app (Flutter) with Supabase-backed gold price updates.

## Run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

## Supabase Setup

Create a Supabase project, then run this SQL in **SQL Editor**:

```sql
create table if not exists public.gold_price_latest (
  id int primary key check (id = 1),
  date text,
  time text,
  image_url text,
  ygea16 int,
  k16_buy int,
  k16_sell int,
  k16new_buy int,
  k16new_sell int,
  k15_buy int,
  k15_sell int,
  k15new_buy int,
  k15new_sell int,
  updated_at timestamptz default now()
);

create table if not exists public.gold_price_history (
  id bigint generated always as identity primary key,
  date text,
  time text,
  image_url text,
  ygea16 int,
  k16_buy int,
  k16_sell int,
  k16new_buy int,
  k16new_sell int,
  k15_buy int,
  k15_sell int,
  k15new_buy int,
  k15new_sell int,
  updated_at timestamptz,
  archived_at timestamptz default now()
);

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);

alter table public.gold_price_latest enable row level security;
alter table public.gold_price_history enable row level security;
alter table public.admins enable row level security;

drop policy if exists "read latest" on public.gold_price_latest;
create policy "read latest" on public.gold_price_latest for select using (true);

drop policy if exists "read history" on public.gold_price_history;
create policy "read history" on public.gold_price_history for select using (true);

drop policy if exists "admin write latest" on public.gold_price_latest;
create policy "admin write latest" on public.gold_price_latest
for all to authenticated
using (exists (select 1 from public.admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admins a where a.user_id = auth.uid()));

drop policy if exists "admin insert history" on public.gold_price_history;
create policy "admin insert history" on public.gold_price_history
for insert to authenticated
with check (exists (select 1 from public.admins a where a.user_id = auth.uid()));

insert into storage.buckets (id, name, public)
values ('gold-images', 'gold-images', true)
on conflict (id) do nothing;
```

## Website-Only Admin Dashboard

- Admin dashboard route: `/admin`
- Example local URL: `http://localhost:PORT/#/admin`
- Admin entry button is shown on **web only**
- Mobile app does not expose admin dashboard
- You can also build a dedicated admin website using `ADMIN_ONLY_WEB=true`

### Create Admin User

1. Supabase Dashboard > Authentication > Users > create user (email/password).
2. Copy that user's `id` (UUID).
3. Insert into `admins` table:

```sql
insert into public.admins(user_id) values ('YOUR_AUTH_USER_UUID');
```

After this, login at `/admin` and update prices/images.

### Build Separate Web Sites (Recommended)

Build normal user site:

```bash
flutter build web \
  --release \
  --output web-build/user \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Build admin-only site:

```bash
flutter build web \
  --release \
  --output web-build/admin \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=ADMIN_ONLY_WEB=true
```

Deploy suggestion:
- `web-build/user` -> `app.yourdomain.com`
- `web-build/admin` -> `admin.yourdomain.com`

## AdMob (Low-interruption full-screen ads)

This app includes interstitial ads with UX guard:
- Show only after user finishes an action (voucher sheet closed)
- Cooldown: `3 minutes`
- Frequency: every `3` completed actions

### Current trigger points
- Calculator result voucher closed
- History voucher closed

### Setup for production
1. Replace AdMob App IDs:
   - Android: `android/app/src/main/AndroidManifest.xml`
   - iOS: `ios/Runner/Info.plist`
2. Replace interstitial Ad Unit IDs in:
   - `lib/shared/ads/interstitial_ad_manager.dart`
3. Keep test ads in development:
   - default uses test IDs (`USE_TEST_ADS=true`)
   - production build example:
     - `flutter build apk --dart-define=USE_TEST_ADS=false`
