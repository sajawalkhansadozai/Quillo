.PHONY: import-recipes import-recipes-json import-recipes-claude deploy-functions set-edge-secrets supabase-login supabase-link

# Supabase CLI via npx (no global `supabase` install required)
SUPABASE := npx --yes supabase@latest

deploy-functions:
	@# Use CLI login token; a stale SUPABASE_ACCESS_TOKEN in the shell causes 401.
	@export SUPABASE_ACCESS_TOKEN=$$(cat $$HOME/.supabase/access-token); \
	$(SUPABASE) functions deploy generate-recipes && \
	$(SUPABASE) functions deploy search-external-recipes && \
	$(SUPABASE) functions deploy fetch-external-recipe && \
	$(SUPABASE) functions deploy generate-recipe-instructions && \
	$(SUPABASE) functions deploy sync-bigoven-grocery

set-edge-secrets:
	@chmod +x scripts/set_edge_secrets.sh
	@./scripts/set_edge_secrets.sh

supabase-login:
	$(SUPABASE) login

supabase-link:
	@test -n "$(PROJECT_REF)" || (echo "Usage: make supabase-link PROJECT_REF=your-project-ref" && exit 1)
	$(SUPABASE) link --project-ref $(PROJECT_REF)

import-recipes:
	@test -n "$(SUPABASE_URL)" || (echo "Missing SUPABASE_URL" && exit 1)
	@test -n "$(SUPABASE_SERVICE_ROLE_KEY)" || (echo "Missing SUPABASE_SERVICE_ROLE_KEY" && exit 1)
	@test -n "$(SEED_USER_ID)" || (echo "Missing SEED_USER_ID" && exit 1)
	@if [ "$${PROVIDER:-spoonacular}" = "spoonacular" ]; then test -n "$(SPOONACULAR_API_KEY)" || (echo "Missing SPOONACULAR_API_KEY for spoonacular provider" && exit 1); fi
	@python3 scripts/import_recipes.py --provider $${PROVIDER:-spoonacular} --total $${TOTAL:-5000} --batch-size $${BATCH_SIZE:-100} --pause-ms $${PAUSE_MS:-250}

import-recipes-json:
	@test -n "$(SUPABASE_URL)" || (echo "Missing SUPABASE_URL" && exit 1)
	@test -n "$(SUPABASE_SERVICE_ROLE_KEY)" || (echo "Missing SUPABASE_SERVICE_ROLE_KEY" && exit 1)
	@test -n "$(SEED_USER_ID)" || (echo "Missing SEED_USER_ID" && exit 1)
	@test -n "$(FILE)" || (echo "Missing FILE (e.g. FILE=data/recipes/sample_recipes.json)" && exit 1)
	@python3 scripts/import_recipes_json.py --file "$(FILE)" --batch-size $${BATCH_SIZE:-50}

import-recipes-claude:
	@test -n "$(SUPABASE_URL)" || (echo "Missing SUPABASE_URL" && exit 1)
	@test -n "$(SUPABASE_SERVICE_ROLE_KEY)" || (echo "Missing SUPABASE_SERVICE_ROLE_KEY" && exit 1)
	@test -n "$(SEED_USER_ID)" || (echo "Missing SEED_USER_ID" && exit 1)
	@test -n "$(ANTHROPIC_API_KEY)" || (echo "Missing ANTHROPIC_API_KEY" && exit 1)
	@python3 scripts/import_recipes_claude.py --total $${TOTAL:-5000} --per-call $${PER_CALL:-10} --pause-ms $${PAUSE_MS:-1500} $(if $(RESUME),--resume,) $(if $(WITH_IMAGES),--with-images,)
