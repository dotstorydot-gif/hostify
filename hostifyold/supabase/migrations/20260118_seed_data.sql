-- ============================================
-- .Hostify - Seed Data
-- Version: 1.0.0
-- Description: Initial seed data for testing
-- ============================================

-- Note: Execute this after running the initial schema migration
-- This creates sample data for development and testing

-- ============================================
-- 1. CREATE ADMIN USER
-- ============================================
-- First, create the admin user through Supabase Auth UI or API
-- Email: info@dot-story.com
-- Password: (set via Supabase dashboard)
-- Then run: INSERT INTO public.user_roles (user_id, role) VALUES ('<admin-uuid>', 'admin');

-- ============================================
-- 2. SAMPLE PROPERTIES
-- ============================================
-- Note: Replace landlord_id with actual user UUID after creating landlord account

INSERT INTO public.properties (name, landlord_id, description, location, address, property_type, bedrooms, bathrooms, max_guests, price_per_night, status)
VALUES 
  (
    'Luxury Villa Hurghada',
    '<landlord-uuid-1>',
    'Stunning beachfront villa with private pool and panoramic Red Sea views. Perfect for families and groups seeking luxury and comfort.',
    'Hurghada',
    'Marina Boulevard, Hurghada, Egypt',
    'villa',
    5,
    4,
    10,
    150.00,
    'active'
  ),
  (
    'Beach House El Gouna',
    '<landlord-uuid-1>',
    'Modern beach house in the heart of El Gouna with direct beach access. Ideal for water sports enthusiasts.',
    'El Gouna',
    'Abu Tig Marina, El Gouna, Egypt',
    'house',
    3,
    2,
    6,
    200.00,
    'active'
  ),
  (
    'Cozy Apartment Cairo',
    '<landlord-uuid-2>',
    'Comfortable apartment in downtown Cairo, close to major attractions and shopping areas.',
    'Cairo',
    'Zamalek District, Cairo, Egypt',
    'apartment',
    2,
    1,
    4,
    80.00,
    'active'
  );

-- ============================================
-- 3. SAMPLE PROPERTY AMENITIES
-- ============================================

-- Luxury Villa Hurghada amenities
INSERT INTO public.property_amenities (property_id, amenity)
SELECT id, unnest(ARRAY['wifi', 'pool', 'parking', 'air_conditioning', 'kitchen', 'beach_access', 'tv', 'washer'])
FROM public.properties WHERE name = 'Luxury Villa Hurghada';

-- Beach House El Gouna amenities
INSERT INTO public.property_amenities (property_id, amenity)
SELECT id, unnest(ARRAY['wifi', 'parking', 'air_conditioning', 'kitchen', 'beach_access', 'tv', 'kayak', 'snorkeling_gear'])
FROM public.properties WHERE name = 'Beach House El Gouna';

-- Cozy Apartment Cairo amenities
INSERT INTO public.property_amenities (property_id, amenity)
SELECT id, unnest(ARRAY['wifi', 'air_conditioning', 'kitchen', 'tv', 'elevator', 'balcony'])
FROM public.properties WHERE name = 'Cozy Apartment Cairo';

-- ============================================
-- 4. SAMPLE REVIEWS
-- ============================================
-- Note: Replace guest_id and property_id with actual UUIDs

INSERT INTO public.reviews (
  property_id,
  guest_id,
  guest_name,
  overall_rating,
  cleanliness_rating,
  location_rating,
  value_rating,
  amenities_rating,
  service_rating,
  accuracy_rating,
  review_text,
  status
)
SELECT 
  p.id,
  '<guest-uuid>',
  'Sarah Johnson',
  5.0,
  5.0,
  4.8,
  4.9,
  4.7,
  5.0,
  4.9,
  'Amazing property! The view was spectacular and the host was very responsive. Would definitely stay again!',
  'published'
FROM public.properties p WHERE p.name = 'Luxury Villa Hurghada'
LIMIT 1;

-- ============================================
-- 5. SAMPLE PROPERTY FINANCIALS
-- ============================================
-- YTD 2026 financials for properties

INSERT INTO public.property_financials (
  property_id,
  period_year,
  period_month,
  total_revenue,
  nights_booked,
  management_fee_percentage
)
SELECT
  id,
  2026,
  NULL, -- NULL = entire year
  12450.00,
  45,
  15.00
FROM public.properties WHERE name = 'Luxury Villa Hurghada';

-- ============================================
-- 6. SAMPLE EXPENSES
-- ============================================

INSERT INTO public.expenses (property_id, title, cost, category, expense_date)
SELECT
  id,
  unnest(ARRAY['Deep Cleaning', 'Pool Maintenance', 'Garden Service', 'Utilities Bill']),
  unnest(ARRAY[500.00, 800.00, 400.00, 400.00]),
  unnest(ARRAY['cleaning', 'maintenance', 'maintenance', 'utilities']),
  unnest(ARRAY['2026-01-05'::date, '2026-01-10'::date, '2026-01-15'::date, '2026-01-20'::date])
FROM public.properties WHERE name = 'Luxury Villa Hurghada';

-- ============================================
-- DEPLOYMENT NOTES
-- ============================================
/*
1. Create these users manually in Supabase Auth before running seed:
   - Admin: info@dot-story.com
   - Landlord 1: info@dot-story.com
   - Landlord 2: landlord2@hostifystays.com
   - Guest: guest@hostifystays.com

2. After creating users, get their UUIDs from auth.users table

3. Replace all <uuid> placeholders in this file with actual UUIDs

4. Run this seed file: psql -d your_db < seed_data.sql

5. Add user roles:
   INSERT INTO public.user_roles (user_id, role) 
   VALUES 
     ('<admin-uuid>', 'admin'),
     ('<landlord-1-uuid>', 'landlord'),
     ('<landlord-2-uuid>', 'landlord'),
     ('<guest-uuid>', 'guest');
*/
