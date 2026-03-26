# RowCraft — Development Commands
# Run `make setup` for first-time setup, then `make dev` to start everything.

LOCAL_IP := $(shell ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $$1}')
SUPABASE_URL := http://$(LOCAL_IP):54321

.PHONY: setup setup-supabase setup-mobile setup-web dev dev-supabase dev-mobile dev-web test test-mobile test-web clean

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
	@echo "  make dev-web       # SvelteKit at http://localhost:5173"
	@echo ""

dev-supabase:
	@supabase status > /dev/null 2>&1 || supabase start

dev-mobile:
	@echo "Starting Flutter app (local IP: $(LOCAL_IP))..."
	$(eval PUB_KEY := $(shell supabase status -o env 2>/dev/null | grep ANON_KEY | cut -d= -f2))
	cd apps/mobile && flutter run \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_PUBLISHABLE_KEY=$(PUB_KEY)

dev-mobile-cloud:
	cd apps/mobile && flutter run \
		--dart-define=SUPABASE_URL=https://qzzqqgnegvuqmlkfqhus.supabase.co \
		--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_-J6qboxKtmCfn_aIBHKX-g_tCFwUWdV

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

clean:
	cd apps/mobile && flutter clean
	cd apps/web && rm -rf node_modules .svelte-kit
	supabase stop

ip:
	@echo "$(LOCAL_IP)"

db-reset:
	supabase db reset

studio:
	@echo "Supabase Studio: http://localhost:54323"
	@open http://localhost:54323

build-apk:
	$(eval PUB_KEY := $(shell supabase status -o env 2>/dev/null | grep ANON_KEY | cut -d= -f2))
	cd apps/mobile && flutter build apk --release \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_PUBLISHABLE_KEY=$(PUB_KEY)
	@echo "APK at apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
