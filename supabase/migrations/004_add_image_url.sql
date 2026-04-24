-- ============================================================
-- Migration 004 — add image_url to recipes table
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

ALTER TABLE public.recipes
  ADD COLUMN IF NOT EXISTS image_url TEXT;
