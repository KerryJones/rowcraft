# RowCraft — Development Commands
# Run `make setup` for first-time setup, then `make dev` to start everything.

LOCAL_IP := $(shell ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $$1}')
SUPABASE_URL := http://$(LOCAL_IP):54321
WEB_APP_URL ?= https://rowcraft.kerryjones.net

.PHONY: list setup setup-supabase setup-mobile setup-web dev dev-supabase dev-mobile dev-web test test-mobile test-web check clean db-reset db-push db-seed build-seeds

# ─── Help ────────────────────────────────────────────────────────────────────

list:
	@echo "Setup:"
	@echo "  make setup            First-time setup (supabase + mobile + web)"
	@echo "  make setup-supabase   Start Supabase and reset DB"
	@echo "  make setup-mobile     Flutter create + pub get + build_runner"
	@echo "  make setup-web        npm install + create .env"
	@echo ""
	@echo "Development:"
	@echo "  make dev              Start Supabase, show instructions"
	@echo "  make dev-web          Start Next.js dev server (http://localhost:3000)"
	@echo "  make dev-mobile       Start Flutter app with local Supabase"
	@echo "  make dev-mobile-cloud Start Flutter app with cloud Supabase"
	@echo ""
	@echo "Testing:"
	@echo "  make test             Run all tests (mobile + web)"
	@echo "  make test-mobile      Flutter tests"
	@echo "  make test-web         Vitest tests"
	@echo "  make check            TypeScript type check (web)"
	@echo ""
	@echo "Database:"
	@echo "  make db-reset         Truncate all data (with confirmation)"
	@echo "  make db-push          Push migrations to linked project"
	@echo "  make db-seed          Run seed.sql on linked project"
	@echo "  make studio           Open Supabase Studio"
	@echo ""
	@echo "Build:"
	@echo "  make build-seeds      Generate SQL seeds from YAML workout definitions"
	@echo "  make build-apk        Build Android APK"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean            Clean all build artifacts"
	@echo "  make ip               Show local IP address"

# ─── First-Time Setup ────────────────────────────────────────────────────────

setup: setup-supabase setup-mobile setup-web
	@echo ""
	@echo "Setup complete. Run 'make dev' to start developing."
	@echo "   Your local IP: $(LOCAL_IP)"
	@echo ""

setup-supabase:
	@echo "Starting Supabase..."
	supabase start
	supabase db reset
	@echo "Supabase ready."

setup-mobile:
	@echo "Setting up Flutter app..."
	cd apps/mobile && flutter create . --org com.rowcraft --platforms android,ios
	cd apps/mobile && flutter pub get
	cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
	@echo "Flutter app ready."

setup-web:
	@echo "Setting up web app..."
	cd apps/web && npm install
	@echo "Creating .env from .env.example..."
	@if [ ! -f apps/web/.env ]; then cp apps/web/.env.example apps/web/.env; fi
	@echo "Web app ready. Edit apps/web/.env with your Supabase credentials."

# ─── Development ─────────────────────────────────────────────────────────────

dev: dev-supabase
	@echo ""
	@echo "Supabase running at $(SUPABASE_URL)"
	@echo "Run in separate terminals:"
	@echo "  make dev-mobile    # Flutter on phone/emulator"
	@echo "  make dev-web       # Next.js at http://localhost:3000"
	@echo ""

dev-supabase:
	@supabase status > /dev/null 2>&1 || supabase start

dev-mobile:
	@echo "Starting Flutter app (local IP: $(LOCAL_IP))..."
	$(eval PUB_KEY := $(shell supabase status -o env 2>/dev/null | grep ANON_KEY | cut -d= -f2))
	cd apps/mobile && flutter run \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_PUBLISHABLE_KEY=$(PUB_KEY) \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=WEB_APP_URL=http://$(LOCAL_IP):3000

dev-mobile-cloud:
	cd apps/mobile && flutter run \
		--dart-define=SUPABASE_URL=https://qzzqqgnegvuqmlkfqhus.supabase.co \
		--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_-J6qboxKtmCfn_aIBHKX-g_tCFwUWdV \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=WEB_APP_URL=$(WEB_APP_URL)

dev-web:
	cd apps/web && npm run dev

# ─── Testing ─────────────────────────────────────────────────────────────────

test: test-mobile test-web
	@echo "All tests passed."

test-mobile:
	cd apps/mobile && flutter test

test-web:
	cd apps/web && npx vitest run

# ─── Utilities ───────────────────────────────────────────────────────────────

check:
	cd apps/web && npm run check

clean:
	cd apps/mobile && flutter clean
	cd apps/web && rm -rf node_modules .next
	supabase stop

ip:
	@echo "$(LOCAL_IP)"

db-reset:
	@echo ""
	@echo "⚠  WARNING: This will DELETE all workouts, plans, results, and FTP history!"
	@echo ""
	@read -p "Type 'reset' to confirm: " confirm && [ "$$confirm" = "reset" ] || (echo "Aborted." && exit 1)
	supabase db query --linked "truncate public.user_plan_progress, public.training_plans, public.workout_results, public.ftp_history, public.workouts cascade"
	@echo "Reset complete. Run 'make db-seed' to re-seed."

db-push:
	supabase db push

db-seed:
	supabase db query --linked --file supabase/seeds/00_functions.sql
	supabase db query --linked --file supabase/seeds/gen_all_workouts.sql
	supabase db query --linked --file supabase/seeds/90_training_plans.sql

studio:
	@echo "Supabase Studio: http://localhost:54323"
	@open http://localhost:54323

build-seeds:
	cd scripts && npx tsx build-seeds.ts

build-apk:
	$(eval PUB_KEY := $(shell supabase status -o env 2>/dev/null | grep ANON_KEY | cut -d= -f2))
	cd apps/mobile && flutter build apk --release \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_PUBLISHABLE_KEY=$(PUB_KEY) \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=WEB_APP_URL=$(WEB_APP_URL)
	@echo "APK at apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
