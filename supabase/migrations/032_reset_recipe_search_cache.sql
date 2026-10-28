-- Search cache v2 (search-catalog): one de-duplicated stream per
-- provider + term + preference set, keyed as 'v2|<provider>|<term>|<prefs hash>'.
--
-- Drop every pre-v2 row:
--  * position-0 cursor rows stored Edamam continuation URLs that included
--    app_id/app_key, and recipe_cache is readable by all signed-in users;
--  * the remaining rows were filtered by whichever user searched first, mixed
--    rows from different fetches, and are never read by v2 anyway.
DELETE FROM public.recipe_cache
WHERE search_term NOT LIKE 'v2|%';
