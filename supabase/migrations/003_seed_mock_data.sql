-- ============================================================
-- Quillo — Mock Seed Data  (v2 — full collection coverage)
-- Run this in: Supabase Dashboard → SQL Editor → New Query
--
-- Automatically uses your first signed-up user's ID.
-- Safe to run multiple times (uses ON CONFLICT DO NOTHING).
-- ============================================================

DO $$
DECLARE
  v_uid uuid;

  -- Scans
  v_scan1_id  uuid := gen_random_uuid();
  v_scan2_id  uuid := gen_random_uuid();
  v_scan3_id  uuid := gen_random_uuid();
  v_scan4_id  uuid := gen_random_uuid();
  v_scan5_id  uuid := gen_random_uuid();
  v_scan6_id  uuid := gen_random_uuid();

  -- Italian Classics
  v_r_italian1  uuid := gen_random_uuid();
  v_r_italian2  uuid := gen_random_uuid();
  v_r_italian3  uuid := gen_random_uuid();

  -- Street Food
  v_r_street1   uuid := gen_random_uuid();
  v_r_street2   uuid := gen_random_uuid();
  v_r_street3   uuid := gen_random_uuid();

  -- Plant Based
  v_r_plant1    uuid := gen_random_uuid();
  v_r_plant2    uuid := gen_random_uuid();
  v_r_plant3    uuid := gen_random_uuid();

  -- Quick Bites (≤20 min)
  v_r_quick1    uuid := gen_random_uuid();
  v_r_quick2    uuid := gen_random_uuid();
  v_r_quick3    uuid := gen_random_uuid();

  -- Asian Flavours
  v_r_asian1    uuid := gen_random_uuid();
  v_r_asian2    uuid := gen_random_uuid();
  v_r_asian3    uuid := gen_random_uuid();

  -- Comfort Food
  v_r_comfort1  uuid := gen_random_uuid();
  v_r_comfort2  uuid := gen_random_uuid();
  v_r_comfort3  uuid := gen_random_uuid();

BEGIN

  -- ── Resolve user ID ──────────────────────────────────────────────────────────
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    SELECT id INTO v_uid FROM public.users ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No user row found. Open the app, sign in, then re-run.';
  END IF;
  RAISE NOTICE 'Seeding data for user_id: %', v_uid;

  -- ── Upsert user row ───────────────────────────────────────────────────────────
  INSERT INTO public.users (id, email, household_size, preferred_cuisine, gdpr_consent, scan_streak, last_scan_date, subscription_status)
  SELECT v_uid, email, 2, ARRAY['Italian','Asian'], true, 6, current_date - 1, 'free'
  FROM auth.users WHERE id = v_uid
  ON CONFLICT (id) DO UPDATE
    SET scan_streak    = 6,
        last_scan_date = current_date - 1;

  INSERT INTO public.user_preferences (user_id, dietary_labels, exclude_ingredients)
  VALUES (v_uid, ARRAY['Vegetarian', 'Gluten Free'], ARRAY['Peanuts'])
  ON CONFLICT (user_id) DO NOTHING;

  -- ── Scans ─────────────────────────────────────────────────────────────────────
  INSERT INTO public.scans (id, user_id, image_url, raw_ocr_text, scan_date, status) VALUES
    (v_scan1_id, v_uid, null, 'Pasta 400g, Parmesan 100g, Pancetta 150g, Eggs 4, Garlic 4 cloves, Olive Oil',       now() - interval '1 day',  'complete'),
    (v_scan2_id, v_uid, null, 'Ground Beef 500g, Burger Buns 4, Cheddar 100g, Lettuce, Tomato 2, Onion 1',          now() - interval '3 days', 'complete'),
    (v_scan3_id, v_uid, null, 'Chickpeas 400g can, Avocado 2, Lemon 2, Spinach 200g, Olive Oil, Garlic 2',          now() - interval '5 days', 'complete'),
    (v_scan4_id, v_uid, null, 'Eggs 6, Bread 1 loaf, Cheddar 200g, Milk 300ml, Tomatoes 3',                         now() - interval '7 days', 'complete'),
    (v_scan5_id, v_uid, null, 'Rice 400g, Soy Sauce, Ginger, Spring Onions, Sesame Oil, Eggs 3, Frozen Peas 200g',  now() - interval '9 days', 'complete'),
    (v_scan6_id, v_uid, null, 'Chicken Thighs 600g, Potatoes 500g, Carrots 3, Onion 2, Celery 3 stalks, Thyme',     now() - interval '12 days','complete')
  ON CONFLICT DO NOTHING;

  -- ════════════════════════════════════════════════════════════════════════════
  -- ITALIAN CLASSICS
  -- ════════════════════════════════════════════════════════════════════════════

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_italian1, v_scan1_id, v_uid,
    'Spaghetti Carbonara',
    25, 'medium', 4,
    '[
      {"order":1,"instruction":"Cook spaghetti in heavily salted boiling water until al dente (9–10 min). Reserve 1 cup pasta water.","duration_minutes":10},
      {"order":2,"instruction":"Fry pancetta in a dry pan until crispy, about 5 minutes. Remove from heat.","duration_minutes":5},
      {"order":3,"instruction":"Whisk eggs with grated parmesan, black pepper and a pinch of salt in a bowl.","duration_minutes":2},
      {"order":4,"instruction":"Drain pasta and immediately toss in the pan with pancetta off the heat. Pour egg mixture over, tossing quickly. Add pasta water, a splash at a time, until silky. Serve immediately.","duration_minutes":4}
    ]'::jsonb,
    '[{"name":"Spaghetti","amount":"400g"},{"name":"Pancetta","amount":"150g"},{"name":"Eggs","amount":"4"},{"name":"Parmesan","amount":"100g"},{"name":"Garlic","amount":"2 cloves"}]'::jsonb,
    '[{"name":"Pecorino Romano","amount":"50g"},{"name":"Black Pepper","amount":"1 tsp"}]'::jsonb,
    '{"calories":610,"protein":32,"carbs":65,"fat":24}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_italian2, v_scan1_id, v_uid,
    'Classic Pesto Pasta',
    20, 'easy', 4,
    '[
      {"order":1,"instruction":"Cook pasta in salted boiling water until al dente, about 10 minutes. Reserve ½ cup pasta water before draining.","duration_minutes":10},
      {"order":2,"instruction":"Blend basil, garlic, parmesan, olive oil and a pinch of salt into a smooth pesto. Add pine nuts if available.","duration_minutes":5},
      {"order":3,"instruction":"Toss hot drained pasta with pesto, loosening with pasta water as needed. Serve with extra parmesan.","duration_minutes":3}
    ]'::jsonb,
    '[{"name":"Pasta","amount":"400g"},{"name":"Parmesan","amount":"80g"},{"name":"Garlic","amount":"2 cloves"},{"name":"Olive Oil","amount":"4 tbsp"}]'::jsonb,
    '[{"name":"Fresh Basil","amount":"2 bunches"},{"name":"Pine Nuts","amount":"30g"}]'::jsonb,
    '{"calories":540,"protein":18,"carbs":70,"fat":22}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_italian3, v_scan1_id, v_uid,
    'Italian Garlic Bruschetta',
    15, 'easy', 6,
    '[
      {"order":1,"instruction":"Slice a baguette diagonally into 1 cm slices. Toast under a grill for 2 minutes each side until golden.","duration_minutes":5},
      {"order":2,"instruction":"Rub each slice with a cut garlic clove while still warm.","duration_minutes":2},
      {"order":3,"instruction":"Dice tomatoes and mix with olive oil, salt, black pepper and torn basil.","duration_minutes":3},
      {"order":4,"instruction":"Spoon tomato mixture onto toasted bread. Drizzle with extra olive oil and serve immediately.","duration_minutes":2}
    ]'::jsonb,
    '[{"name":"Garlic","amount":"4 cloves"},{"name":"Olive Oil","amount":"3 tbsp"},{"name":"Tomatoes","amount":"4 large"}]'::jsonb,
    '[{"name":"Baguette","amount":"1"},{"name":"Fresh Basil","amount":"handful"}]'::jsonb,
    '{"calories":210,"protein":5,"carbs":30,"fat":8}'::jsonb
  ) ON CONFLICT DO NOTHING;

  -- ════════════════════════════════════════════════════════════════════════════
  -- STREET FOOD
  -- ════════════════════════════════════════════════════════════════════════════

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_street1, v_scan2_id, v_uid,
    'Classic Beef Burger',
    20, 'easy', 4,
    '[
      {"order":1,"instruction":"Season ground beef with salt, pepper and garlic powder. Shape into 4 patties about 2 cm thick.","duration_minutes":5},
      {"order":2,"instruction":"Cook patties in a hot cast-iron pan for 4 minutes each side. Add cheddar slice in the last minute.","duration_minutes":9},
      {"order":3,"instruction":"Toast burger buns on the cut side in the pan for 1 minute.","duration_minutes":2},
      {"order":4,"instruction":"Assemble with lettuce, sliced tomato, onion rings and your preferred sauces.","duration_minutes":3}
    ]'::jsonb,
    '[{"name":"Ground Beef","amount":"500g"},{"name":"Burger Buns","amount":"4"},{"name":"Cheddar","amount":"4 slices"},{"name":"Lettuce","amount":"4 leaves"},{"name":"Tomato","amount":"1 large"},{"name":"Onion","amount":"1"}]'::jsonb,
    '[{"name":"Ketchup","amount":"2 tbsp"},{"name":"Mustard","amount":"1 tbsp"},{"name":"Pickles","amount":"handful"}]'::jsonb,
    '{"calories":680,"protein":45,"carbs":40,"fat":38}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_street2, v_scan2_id, v_uid,
    'Beef Kebab Wrap',
    25, 'easy', 4,
    '[
      {"order":1,"instruction":"Mix ground beef with garlic, onion, cumin, paprika, salt and pepper. Shape into long sausages around skewers.","duration_minutes":8},
      {"order":2,"instruction":"Grill kebabs over medium-high heat for 12–14 minutes, turning every 3–4 minutes until charred and cooked through.","duration_minutes":14},
      {"order":3,"instruction":"Warm flatbreads for 30 seconds each side on a dry pan.","duration_minutes":2},
      {"order":4,"instruction":"Wrap kebab in flatbread with sliced onion, tomato, lettuce and a drizzle of yogurt sauce.","duration_minutes":3}
    ]'::jsonb,
    '[{"name":"Ground Beef","amount":"400g"},{"name":"Onion","amount":"1"},{"name":"Tomato","amount":"2"},{"name":"Lettuce","amount":"handful"}]'::jsonb,
    '[{"name":"Flatbreads","amount":"4"},{"name":"Cumin","amount":"1 tsp"},{"name":"Paprika","amount":"1 tsp"},{"name":"Greek Yogurt","amount":"100ml"}]'::jsonb,
    '{"calories":520,"protein":38,"carbs":38,"fat":22}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_street3, v_scan2_id, v_uid,
    'Cheesy Beef Sandwich',
    15, 'easy', 2,
    '[
      {"order":1,"instruction":"Thinly slice beef and cook in a hot pan with onion until caramelised, about 8 minutes.","duration_minutes":8},
      {"order":2,"instruction":"Add cheddar slices over the meat and cover pan for 1 minute until melted.","duration_minutes":1},
      {"order":3,"instruction":"Toast bread slices. Load with the cheesy beef and top with lettuce and sliced tomato.","duration_minutes":4}
    ]'::jsonb,
    '[{"name":"Beef","amount":"300g"},{"name":"Cheddar","amount":"80g"},{"name":"Onion","amount":"1"},{"name":"Lettuce","amount":"2 leaves"},{"name":"Tomato","amount":"1"}]'::jsonb,
    '[{"name":"Hoagie Rolls","amount":"2"},{"name":"Bell Pepper","amount":"1"}]'::jsonb,
    '{"calories":590,"protein":40,"carbs":35,"fat":30}'::jsonb
  ) ON CONFLICT DO NOTHING;

  -- ════════════════════════════════════════════════════════════════════════════
  -- PLANT BASED
  -- ════════════════════════════════════════════════════════════════════════════

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_plant1, v_scan3_id, v_uid,
    'Chickpea & Avocado Salad',
    15, 'easy', 2,
    '[
      {"order":1,"instruction":"Drain and rinse chickpeas. Pat dry and season with olive oil, salt and paprika.","duration_minutes":3},
      {"order":2,"instruction":"Dice avocado and tomato. Slice red onion thinly.","duration_minutes":4},
      {"order":3,"instruction":"Toss spinach, chickpeas, avocado, tomato and onion together. Dress with lemon juice, olive oil and salt.","duration_minutes":3}
    ]'::jsonb,
    '[{"name":"Chickpeas","amount":"400g"},{"name":"Avocado","amount":"2"},{"name":"Spinach","amount":"100g"},{"name":"Lemon","amount":"1"},{"name":"Olive Oil","amount":"2 tbsp"}]'::jsonb,
    '[{"name":"Cherry Tomatoes","amount":"150g"},{"name":"Red Onion","amount":"½"},{"name":"Paprika","amount":"½ tsp"}]'::jsonb,
    '{"calories":380,"protein":14,"carbs":38,"fat":20}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_plant2, v_scan3_id, v_uid,
    'Lentil & Spinach Soup',
    35, 'easy', 4,
    '[
      {"order":1,"instruction":"Sauté diced onion and garlic in olive oil for 5 minutes until softened.","duration_minutes":5},
      {"order":2,"instruction":"Add red lentils, vegetable stock and cumin. Bring to a boil then simmer for 20 minutes.","duration_minutes":22},
      {"order":3,"instruction":"Stir in fresh spinach and lemon juice. Cook for 2 more minutes until spinach wilts.","duration_minutes":3},
      {"order":4,"instruction":"Blend partially for a creamier texture or serve chunky. Season to taste.","duration_minutes":3}
    ]'::jsonb,
    '[{"name":"Spinach","amount":"200g"},{"name":"Garlic","amount":"2 cloves"},{"name":"Olive Oil","amount":"2 tbsp"},{"name":"Lemon","amount":"1"}]'::jsonb,
    '[{"name":"Red Lentils","amount":"300g"},{"name":"Vegetable Stock","amount":"1.2L"},{"name":"Cumin","amount":"1 tsp"},{"name":"Onion","amount":"1"}]'::jsonb,
    '{"calories":290,"protein":18,"carbs":42,"fat":6}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_plant3, v_scan3_id, v_uid,
    'Avocado & Bean Toast',
    10, 'easy', 2,
    '[
      {"order":1,"instruction":"Toast bread until golden and crispy.","duration_minutes":3},
      {"order":2,"instruction":"Drain and rinse black beans. Mash roughly with a fork with salt, cumin and lime juice.","duration_minutes":3},
      {"order":3,"instruction":"Spread bean mash on toast. Top with sliced avocado, a pinch of chilli flakes and lemon zest.","duration_minutes":3}
    ]'::jsonb,
    '[{"name":"Avocado","amount":"1"},{"name":"Lemon","amount":"1"}]'::jsonb,
    '[{"name":"Sourdough Bread","amount":"4 slices"},{"name":"Black Beans","amount":"400g can"},{"name":"Chilli Flakes","amount":"pinch"},{"name":"Cumin","amount":"½ tsp"}]'::jsonb,
    '{"calories":320,"protein":10,"carbs":36,"fat":16}'::jsonb
  ) ON CONFLICT DO NOTHING;

  -- ════════════════════════════════════════════════════════════════════════════
  -- QUICK BITES (≤ 20 min)
  -- ════════════════════════════════════════════════════════════════════════════

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_quick1, v_scan4_id, v_uid,
    'Cheesy Scrambled Eggs on Toast',
    10, 'easy', 2,
    '[
      {"order":1,"instruction":"Toast 2 slices of bread. Whisk 4 eggs with milk, salt and pepper.","duration_minutes":3},
      {"order":2,"instruction":"Melt butter in a non-stick pan over low heat. Add eggs and stir slowly until just set and creamy, about 4 minutes.","duration_minutes":4},
      {"order":3,"instruction":"Stir in grated cheddar off the heat. Serve immediately on toast.","duration_minutes":2}
    ]'::jsonb,
    '[{"name":"Eggs","amount":"4"},{"name":"Milk","amount":"2 tbsp"},{"name":"Cheddar","amount":"50g"},{"name":"Bread","amount":"2 slices"}]'::jsonb,
    '[{"name":"Butter","amount":"1 tbsp"},{"name":"Chives","amount":"1 tbsp"}]'::jsonb,
    '{"calories":390,"protein":26,"carbs":22,"fat":22}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_quick2, v_scan4_id, v_uid,
    'Quick Tomato Omelette',
    12, 'easy', 1,
    '[
      {"order":1,"instruction":"Whisk 3 eggs with a splash of milk, salt and pepper.","duration_minutes":2},
      {"order":2,"instruction":"Dice tomatoes finely. Heat olive oil in a non-stick pan over medium heat.","duration_minutes":2},
      {"order":3,"instruction":"Pour in egg mixture. Scatter tomatoes and cheddar over one half. Cook for 3–4 minutes until set, then fold and serve.","duration_minutes":5}
    ]'::jsonb,
    '[{"name":"Eggs","amount":"3"},{"name":"Milk","amount":"1 tbsp"},{"name":"Tomatoes","amount":"2"},{"name":"Cheddar","amount":"40g"}]'::jsonb,
    '[{"name":"Fresh Herbs","amount":"pinch"}]'::jsonb,
    '{"calories":310,"protein":22,"carbs":8,"fat":21}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_quick3, v_scan4_id, v_uid,
    'Cheesy Bread Toastie',
    8, 'easy', 2,
    '[
      {"order":1,"instruction":"Butter one side of each bread slice. Layer cheddar between two slices, butter-side out.","duration_minutes":2},
      {"order":2,"instruction":"Cook in a pan over medium heat for 3 minutes each side, pressing down with a spatula, until golden and cheese is melted.","duration_minutes":6}
    ]'::jsonb,
    '[{"name":"Bread","amount":"4 slices"},{"name":"Cheddar","amount":"100g"}]'::jsonb,
    '[{"name":"Butter","amount":"2 tbsp"},{"name":"Dijon Mustard","amount":"1 tsp"}]'::jsonb,
    '{"calories":420,"protein":18,"carbs":38,"fat":24}'::jsonb
  ) ON CONFLICT DO NOTHING;

  -- ════════════════════════════════════════════════════════════════════════════
  -- ASIAN FLAVOURS
  -- ════════════════════════════════════════════════════════════════════════════

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_asian1, v_scan5_id, v_uid,
    'Egg Fried Rice',
    18, 'easy', 3,
    '[
      {"order":1,"instruction":"Cook rice according to packet instructions. Spread on a tray and cool for 10 minutes (or use day-old rice).","duration_minutes":5},
      {"order":2,"instruction":"Heat sesame oil in a wok over high heat. Add garlic and ginger, stir-fry for 30 seconds.","duration_minutes":2},
      {"order":3,"instruction":"Push ingredients to one side. Scramble eggs in the space, then mix into the wok.","duration_minutes":3},
      {"order":4,"instruction":"Add rice, peas and spring onions. Toss everything together with soy sauce for 4–5 minutes.","duration_minutes":5}
    ]'::jsonb,
    '[{"name":"Rice","amount":"300g"},{"name":"Eggs","amount":"3"},{"name":"Soy Sauce","amount":"3 tbsp"},{"name":"Spring Onions","amount":"4"},{"name":"Sesame Oil","amount":"1 tbsp"},{"name":"Frozen Peas","amount":"200g"}]'::jsonb,
    '[{"name":"Ginger","amount":"1 tsp"},{"name":"Garlic","amount":"2 cloves"}]'::jsonb,
    '{"calories":420,"protein":16,"carbs":68,"fat":10}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_asian2, v_scan5_id, v_uid,
    'Teriyaki Chicken Stir Fry',
    25, 'medium', 3,
    '[
      {"order":1,"instruction":"Slice chicken thinly. Mix soy sauce, sesame oil, a pinch of sugar and ginger into a teriyaki glaze.","duration_minutes":5},
      {"order":2,"instruction":"Heat a wok over high heat. Stir-fry chicken for 5–6 minutes until golden.","duration_minutes":6},
      {"order":3,"instruction":"Add vegetables and stir-fry for 4–5 minutes. Pour glaze over everything.","duration_minutes":5},
      {"order":4,"instruction":"Serve over cooked rice, garnished with spring onions and sesame seeds.","duration_minutes":5}
    ]'::jsonb,
    '[{"name":"Rice","amount":"250g"},{"name":"Soy Sauce","amount":"4 tbsp"},{"name":"Spring Onions","amount":"3"},{"name":"Sesame Oil","amount":"1 tbsp"},{"name":"Ginger","amount":"1 tsp"}]'::jsonb,
    '[{"name":"Chicken Thighs","amount":"400g"},{"name":"Mixed Vegetables","amount":"300g"},{"name":"Sugar","amount":"1 tbsp"},{"name":"Sesame Seeds","amount":"1 tsp"}]'::jsonb,
    '{"calories":490,"protein":36,"carbs":55,"fat":14}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_asian3, v_scan5_id, v_uid,
    'Miso Soup with Spring Onions',
    15, 'easy', 2,
    '[
      {"order":1,"instruction":"Bring 600ml water to a gentle simmer. Dissolve miso paste in a small amount of hot water first to avoid lumps.","duration_minutes":5},
      {"order":2,"instruction":"Add miso liquid to the pot. Do not boil — keep at a gentle simmer.","duration_minutes":3},
      {"order":3,"instruction":"Add cubed silken tofu and sliced spring onions. Warm through for 2–3 minutes.","duration_minutes":3},
      {"order":4,"instruction":"Ladle into bowls. Top with sesame oil and extra spring onions.","duration_minutes":2}
    ]'::jsonb,
    '[{"name":"Spring Onions","amount":"4"},{"name":"Sesame Oil","amount":"1 tsp"}]'::jsonb,
    '[{"name":"White Miso Paste","amount":"3 tbsp"},{"name":"Silken Tofu","amount":"150g"},{"name":"Dried Wakame","amount":"1 tsp"}]'::jsonb,
    '{"calories":120,"protein":8,"carbs":10,"fat":5}'::jsonb
  ) ON CONFLICT DO NOTHING;

  -- ════════════════════════════════════════════════════════════════════════════
  -- COMFORT FOOD
  -- ════════════════════════════════════════════════════════════════════════════

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_comfort1, v_scan6_id, v_uid,
    'Chicken & Vegetable Pot Stew',
    55, 'medium', 4,
    '[
      {"order":1,"instruction":"Brown chicken thighs in olive oil in a large pot over medium-high heat, about 5 minutes each side. Remove and set aside.","duration_minutes":10},
      {"order":2,"instruction":"In the same pot, sauté diced onion, carrots and celery for 5 minutes until softened.","duration_minutes":5},
      {"order":3,"instruction":"Return chicken. Add halved potatoes, thyme and enough water to cover. Season generously.","duration_minutes":5},
      {"order":4,"instruction":"Bring to a boil, then simmer covered for 30–35 minutes until chicken falls off the bone and potatoes are tender.","duration_minutes":32}
    ]'::jsonb,
    '[{"name":"Chicken Thighs","amount":"600g"},{"name":"Potatoes","amount":"500g"},{"name":"Carrots","amount":"3"},{"name":"Onion","amount":"2"},{"name":"Celery","amount":"3 stalks"},{"name":"Thyme","amount":"4 sprigs"}]'::jsonb,
    '[{"name":"Chicken Stock","amount":"500ml"},{"name":"Bay Leaf","amount":"2"}]'::jsonb,
    '{"calories":510,"protein":42,"carbs":40,"fat":18}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_comfort2, v_scan6_id, v_uid,
    'Roast Chicken with Mashed Potatoes',
    70, 'medium', 4,
    '[
      {"order":1,"instruction":"Preheat oven to 220°C. Pat chicken dry. Rub all over with olive oil, salt, pepper and thyme.","duration_minutes":8},
      {"order":2,"instruction":"Roast for 45–50 minutes until skin is golden and juices run clear.","duration_minutes":50},
      {"order":3,"instruction":"Boil potatoes until tender, about 15 minutes. Drain and mash with butter and milk. Season well.","duration_minutes":18},
      {"order":4,"instruction":"Rest chicken for 10 minutes before carving. Serve with mash and roasting juices.","duration_minutes":10}
    ]'::jsonb,
    '[{"name":"Chicken Thighs","amount":"600g"},{"name":"Potatoes","amount":"500g"},{"name":"Thyme","amount":"3 sprigs"},{"name":"Onion","amount":"1"}]'::jsonb,
    '[{"name":"Butter","amount":"50g"},{"name":"Milk","amount":"100ml"},{"name":"Olive Oil","amount":"2 tbsp"}]'::jsonb,
    '{"calories":620,"protein":48,"carbs":42,"fat":28}'::jsonb
  ) ON CONFLICT DO NOTHING;

  INSERT INTO public.recipes (id, scan_id, user_id, title, cook_time_minutes, difficulty, servings, steps, ingredients_used, missing_ingredients, nutrition)
  VALUES (
    v_r_comfort3, v_scan6_id, v_uid,
    'Hearty Vegetable Soup',
    40, 'easy', 4,
    '[
      {"order":1,"instruction":"Dice all vegetables into 1.5 cm cubes. Sauté onion in olive oil for 4 minutes.","duration_minutes":6},
      {"order":2,"instruction":"Add carrots, celery and potatoes. Cook for 3 minutes.","duration_minutes":3},
      {"order":3,"instruction":"Pour in 1.5L of water, add thyme and season. Bring to a boil.","duration_minutes":5},
      {"order":4,"instruction":"Simmer for 20–25 minutes until all vegetables are tender. Adjust seasoning and serve with crusty bread.","duration_minutes":24}
    ]'::jsonb,
    '[{"name":"Potatoes","amount":"300g"},{"name":"Carrots","amount":"2"},{"name":"Celery","amount":"2 stalks"},{"name":"Onion","amount":"1"},{"name":"Thyme","amount":"3 sprigs"}]'::jsonb,
    '[{"name":"Vegetable Stock","amount":"1.5L"},{"name":"Crusty Bread","amount":"to serve"}]'::jsonb,
    '{"calories":220,"protein":6,"carbs":40,"fat":4}'::jsonb
  ) ON CONFLICT DO NOTHING;

  -- ── Saved Recipes (bookmark a few across categories) ─────────────────────────
  INSERT INTO public.saved_recipes (user_id, recipe_id, saved_at, cached_data)
  SELECT v_uid, r.id, r.saved_at, r.data FROM (VALUES
    (v_r_italian1, now() - interval '1 day',
     jsonb_build_object('id',v_r_italian1,'title','Spaghetti Carbonara','difficulty','medium','cook_time_minutes',25,'servings',4,
       'steps','[]'::jsonb,'ingredients_used','[]'::jsonb,'missing_ingredients','[]'::jsonb,
       'nutrition','{"calories":610,"protein":32,"carbs":65,"fat":24}'::jsonb)),
    (v_r_asian1,   now() - interval '2 days',
     jsonb_build_object('id',v_r_asian1,'title','Egg Fried Rice','difficulty','easy','cook_time_minutes',18,'servings',3,
       'steps','[]'::jsonb,'ingredients_used','[]'::jsonb,'missing_ingredients','[]'::jsonb,
       'nutrition','{"calories":420,"protein":16,"carbs":68,"fat":10}'::jsonb)),
    (v_r_plant1,   now() - interval '4 days',
     jsonb_build_object('id',v_r_plant1,'title','Chickpea & Avocado Salad','difficulty','easy','cook_time_minutes',15,'servings',2,
       'steps','[]'::jsonb,'ingredients_used','[]'::jsonb,'missing_ingredients','[]'::jsonb,
       'nutrition','{"calories":380,"protein":14,"carbs":38,"fat":20}'::jsonb)),
    (v_r_comfort1, now() - interval '6 days',
     jsonb_build_object('id',v_r_comfort1,'title','Chicken & Vegetable Pot Stew','difficulty','medium','cook_time_minutes',55,'servings',4,
       'steps','[]'::jsonb,'ingredients_used','[]'::jsonb,'missing_ingredients','[]'::jsonb,
       'nutrition','{"calories":510,"protein":42,"carbs":40,"fat":18}'::jsonb))
  ) AS r(id, saved_at, data)
  ON CONFLICT (user_id, recipe_id) DO NOTHING;

  RAISE NOTICE 'Seed complete for user: %', v_uid;
  RAISE NOTICE '  Scans:         6';
  RAISE NOTICE '  Recipes:       18  (3 per collection × 6 collections)';
  RAISE NOTICE '  Saved:         4';
  RAISE NOTICE '  Streak:        6 days';

END $$;
