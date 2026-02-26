-- 1. Create Property Managers Table
CREATE TABLE IF NOT EXISTS property_managers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(property_id, user_id)
);

-- Enable RLS
ALTER TABLE property_managers ENABLE ROW LEVEL SECURITY;

-- 2. RLS Policies for property_managers
-- Owner can manage managers
CREATE POLICY "Landlords can manage managers for their properties" 
ON property_managers
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM properties 
    WHERE id = property_managers.property_id 
    AND landlord_id = auth.uid()
  )
);

-- Managers can view themselves
CREATE POLICY "Managers can view their assignments" 
ON property_managers
FOR SELECT
USING (auth.uid() = user_id);


-- 3. Update Properties RLS to include Managers (in addition to existing Owner policy)
-- (Dropping old if strict, but adding OR logic via a new policy is cleaner or updating existing)
-- Check existing policies: "Landlords can view their own properties" usually checks landlord_id = auth.uid()

CREATE POLICY "Managers can view assigned properties"
ON properties
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM property_managers 
    WHERE property_id = id 
    AND user_id = auth.uid()
  )
);

-- Managers can update assigned properties
CREATE POLICY "Managers can update assigned properties"
ON properties
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM property_managers 
    WHERE property_id = id 
    AND user_id = auth.uid()
  )
);


-- 4. RPC to Get All Properties (Owned + Managed)
CREATE OR REPLACE FUNCTION get_my_properties(p_user_id UUID)
RETURNS SETOF properties
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT *
  FROM properties
  WHERE landlord_id = p_user_id
     OR id IN (
       SELECT property_id 
       FROM property_managers 
       WHERE user_id = p_user_id
     )
  ORDER BY created_at DESC;
$$;


-- 5. Updated Landlord Analytics RPC to include managed properties
CREATE OR REPLACE FUNCTION get_landlord_analytics(
  p_landlord_id UUID,
  p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_revenue DECIMAL(12, 2) := 0;
  v_total_bookings INTEGER := 0;
  v_occupancy_rate DECIMAL(5, 2) := 0;
  v_avg_rating DECIMAL(3, 2) := 0;
  v_revenue_by_month JSONB;
  v_bookings_by_nationality JSONB;
  v_bookings_by_unit JSONB;
  v_bookings_by_guest_type JSONB;
  v_total_days_in_year INTEGER := 365;
  v_property_count INTEGER;
BEGIN
  -- 1. Get Property Count (Owned + Managed)
  SELECT COUNT(*) INTO v_property_count 
  FROM properties 
  WHERE (landlord_id = p_landlord_id 
         OR id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
    AND status = 'Active';

  -- 2. Total Revenue & Bookings
  SELECT 
    COALESCE(SUM(total_price), 0),
    COUNT(*)
  INTO v_total_revenue, v_total_bookings
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE (p.landlord_id = p_landlord_id 
         OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
    AND b.status IN ('confirmed', 'completed', 'active')
    AND EXTRACT(YEAR FROM b.check_in) = p_year;

  -- 3. Average Rating
  SELECT COALESCE(AVG(overall_rating), 0)
  INTO v_avg_rating
  FROM reviews r
  JOIN properties p ON r.property_id = p.id
  WHERE (p.landlord_id = p_landlord_id 
         OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id));

  -- 4. Occupancy Rate
  IF v_property_count > 0 THEN
    SELECT 
      COALESCE((SUM(nights)::DECIMAL / (v_property_count * v_total_days_in_year)) * 100, 0)
    INTO v_occupancy_rate
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE (p.landlord_id = p_landlord_id 
           OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
      AND b.status IN ('confirmed', 'completed', 'active')
      AND EXTRACT(YEAR FROM b.check_in) = p_year;
  END IF;

  -- 5. Revenue by Month
  SELECT jsonb_object_agg(to_char(month_date, 'Mon'), revenue)
  INTO v_revenue_by_month
  FROM (
    SELECT 
      DATE_TRUNC('month', b.check_in) as month_date,
      SUM(b.total_price) as revenue
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE (p.landlord_id = p_landlord_id 
           OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
      AND b.status IN ('confirmed', 'completed', 'active')
      AND EXTRACT(YEAR FROM b.check_in) = p_year
    GROUP BY DATE_TRUNC('month', b.check_in)
    ORDER BY DATE_TRUNC('month', b.check_in)
  ) m;

  -- 6. Bookings by Unit
  SELECT jsonb_object_agg(name, booking_count)
  INTO v_bookings_by_unit
  FROM (
    SELECT 
      p.name,
      COUNT(*) as booking_count
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE (p.landlord_id = p_landlord_id 
           OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
      AND b.status IN ('confirmed', 'completed', 'active')
      AND EXTRACT(YEAR FROM b.check_in) = p_year
    GROUP BY p.name
    ORDER BY booking_count DESC
    LIMIT 10
  ) u;

  -- 7. Bookings by Nationality 
  SELECT jsonb_object_agg(COALESCE(nationality, 'Unknown'), count)
  INTO v_bookings_by_nationality
  FROM (
      SELECT 
        CASE 
          WHEN b.booking_source = 'airbnb' THEN 'Airbnb User'
          WHEN b.booking_source = 'booking_com' THEN 'Booking.com User'
          ELSE 'Hostify User' 
        END as nationality,
        COUNT(*) as count
      FROM bookings b
      JOIN properties p ON b.property_id = p.id
      WHERE (p.landlord_id = p_landlord_id 
             OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
        AND EXTRACT(YEAR FROM b.check_in) = p_year
      GROUP BY nationality
  ) n;
  
  -- 8. Bookings by Guest Type
  SELECT jsonb_object_agg(guest_type, count)
  INTO v_bookings_by_guest_type
  FROM (
      SELECT 
        CASE 
           WHEN max_guests <= 2 THEN 'Couple'
           WHEN max_guests <= 4 THEN 'Small Family'
           ELSE 'Group/Large Family'
        END as guest_type,
        COUNT(*) as count
      FROM bookings b
      JOIN properties p ON b.property_id = p.id
      WHERE (p.landlord_id = p_landlord_id 
             OR p.id IN (SELECT property_id FROM property_managers WHERE user_id = p_landlord_id))
        AND EXTRACT(YEAR FROM b.check_in) = p_year
      GROUP BY guest_type
  ) g;


  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_bookings', v_total_bookings,
    'occupancy_rate', ROUND(v_occupancy_rate, 1),
    'avg_rating', ROUND(v_avg_rating, 1),
    'revenue_by_month', COALESCE(v_revenue_by_month, '{}'::jsonb),
    'bookings_by_unit', COALESCE(v_bookings_by_unit, '{}'::jsonb),
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
    'bookings_by_guest_type', COALESCE(v_bookings_by_guest_type, '{}'::jsonb)
  );
END;
$$;


-- 6. Assignment Script for Asmaa and Samy
DO $$
DECLARE
  v_asmaa_id UUID;
  v_samy_id UUID;
  v_property_id UUID;
BEGIN
  -- Get User IDs
  SELECT id INTO v_asmaa_id FROM auth.users WHERE email = 'asmaa.elkhatib@gmail.com';
  SELECT id INTO v_samy_id FROM auth.users WHERE email = 'samynegm@torath-co.com';

  -- Get Property ID for "Six Ensuite Amazing 5 Master"
  SELECT id INTO v_property_id 
  FROM properties 
  WHERE name ILIKE '%Six Ensuite%' OR name ILIKE '%5 Master%' 
  LIMIT 1;

  -- 1. Ensure Asmaa is the OWNER
  IF v_asmaa_id IS NOT NULL AND v_property_id IS NOT NULL THEN
     UPDATE properties SET landlord_id = v_asmaa_id WHERE id = v_property_id;
  END IF;

  -- 2. Ensure Samy is a MANAGER
  IF v_samy_id IS NOT NULL AND v_property_id IS NOT NULL THEN
     INSERT INTO property_managers (property_id, user_id)
     VALUES (v_property_id, v_samy_id)
     ON CONFLICT (property_id, user_id) DO NOTHING;
  END IF;

END $$;
