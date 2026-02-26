-- Multi-Landlord System Migration

-- 1. Create Junction Table
CREATE TABLE IF NOT EXISTS public.property_landlords (
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (property_id, user_id)
);

-- 2. Migrate existing landlord_id data
INSERT INTO public.property_landlords (property_id, user_id)
SELECT id, landlord_id
FROM public.properties
WHERE landlord_id IS NOT NULL
ON CONFLICT (property_id, user_id) DO NOTHING;

-- 3. Enable RLS
ALTER TABLE public.property_landlords ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for property_landlords
-- Admins can view/edit all
DROP POLICY IF EXISTS "Admins can do everything on property_landlords" ON public.property_landlords;
CREATE POLICY "Admins can do everything on property_landlords"
ON public.property_landlords
FOR ALL
USING (
    EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin')
);

-- Landlords can view their own assignments
DROP POLICY IF EXISTS "Landlords can view own assignments" ON public.property_landlords;
CREATE POLICY "Landlords can view own assignments"
ON public.property_landlords
FOR SELECT
USING (user_id = auth.uid());

-- 5. Update Properties RLS to use junction table (Viewer access)
-- "Landlords can view assigned properties"
DROP POLICY IF EXISTS "Landlords can view assigned properties" ON public.properties;
CREATE POLICY "Landlords can view assigned properties"
ON public.properties
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM property_landlords pl 
        WHERE pl.property_id = id AND pl.user_id = auth.uid()
    )
    OR 
    landlord_id = auth.uid() -- Keep backward compatibility for now
    OR 
    EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin')
);

-- 6. Update Analytics RPC to use junction table
CREATE OR REPLACE FUNCTION get_landlord_analytics_with_expenses(
  p_landlord_id UUID,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_property_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_start DATE := COALESCE(p_start_date, DATE_TRUNC('year', CURRENT_DATE)::DATE);
  v_end DATE := COALESCE(p_end_date, DATE_TRUNC('year', CURRENT_DATE)::DATE + INTERVAL '1 year' - INTERVAL '1 day');
  v_total_revenue DECIMAL(12, 2) := 0;
  v_total_bookings INTEGER := 0;
  v_total_booked_nights INTEGER := 0;
  v_total_expenses DECIMAL(12, 2) := 0;
  v_total_management_fees DECIMAL(12, 2) := 0;
  v_landlord_share DECIMAL(12, 2) := 0;
  v_occupancy_rate DECIMAL(5, 2) := 0;
  v_avg_rating DECIMAL(3, 2) := 0;
  v_revenue_by_month JSONB;
  v_expenses_by_category JSONB;
  v_expenses_by_property JSONB;
  v_bookings_by_nationality JSONB;
  v_bookings_by_unit JSONB;
  v_bookings_by_guest_type JSONB;
  v_bookings_by_source JSONB;
  v_property_count INTEGER;
  v_total_days INTEGER;
  v_app_bookings INTEGER := 0;
  v_ical_bookings INTEGER := 0;
BEGIN
  v_total_days := (v_end - v_start) + 1;
  IF v_total_days <= 0 THEN v_total_days := 1; END IF;

  -- Property Count (Assigned via property_landlords OR owner)
  SELECT COUNT(*) INTO v_property_count 
  FROM properties p
  WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND p.status = 'active'
    AND (p_property_id IS NULL OR p.id = p_property_id);

  -- Financials
  SELECT 
    COALESCE(SUM(
      CASE 
        WHEN b.total_price > 0 THEN b.total_price 
        ELSE (b.nights * COALESCE(NULLIF(p.price_per_night, 0), 150)) 
      END
    ), 0),
    COUNT(*),
    COALESCE(SUM(nights), 0)
  INTO v_total_revenue, v_total_bookings, v_total_booked_nights
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= v_start AND b.check_in <= v_end
    AND (p_property_id IS NULL OR b.property_id = p_property_id);

  -- Expenses
  SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
  FROM expenses e
  JOIN properties p ON e.property_id = p.id
  WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND e.expense_date >= v_start AND e.expense_date <= v_end
    AND (p_property_id IS NULL OR e.property_id = p_property_id);

  -- Management Fees
  SELECT COALESCE(SUM(
    (CASE 
        WHEN b.total_price > 0 THEN b.total_price 
        ELSE (b.nights * COALESCE(NULLIF(p.price_per_night, 0), 150)) 
     END) 
    * COALESCE(ps.management_fee_percentage, 15.00) / 100
  ), 0)
  INTO v_total_management_fees
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  LEFT JOIN property_settings ps ON ps.property_id = p.id
  WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= v_start AND b.check_in <= v_end
    AND (p_property_id IS NULL OR b.property_id = p_property_id);

  v_landlord_share := v_total_revenue - v_total_expenses - v_total_management_fees;

  -- Occupancy
  IF v_property_count > 0 THEN
    v_occupancy_rate := COALESCE((v_total_booked_nights::DECIMAL / (v_property_count * v_total_days)) * 100, 0);
  END IF;

  -- Rating
  SELECT COALESCE(AVG(overall_rating), 0) INTO v_avg_rating
  FROM reviews r
  JOIN properties p ON r.property_id = p.id
  WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND (p_property_id IS NULL OR p.id = p_property_id);

  -- Nationality 
  SELECT jsonb_object_agg(COALESCE(nat, 'Unknown'), count)
  INTO v_bookings_by_nationality
  FROM (
    SELECT 
      CASE 
        WHEN up.nationality IS NOT NULL THEN up.nationality 
        WHEN b.external_booking_id IS NOT NULL THEN 'International (iCal)'
        ELSE 'Unknown'
      END as nat,
      COUNT(*) as count
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    LEFT JOIN user_profiles up ON b.guest_id = up.id
    WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND b.check_in >= v_start AND b.check_in <= v_end
      AND (p_property_id IS NULL OR b.property_id = p_property_id)
    GROUP BY nat
  ) n;

  -- Guest Type
  SELECT jsonb_object_agg(gtype, count)
  INTO v_bookings_by_guest_type
  FROM (
    SELECT 
      CASE 
        WHEN b.guest_count = 1 THEN 'Individual'
        WHEN b.guest_count = 2 THEN 'Couple'
        WHEN b.guest_count BETWEEN 3 AND 5 THEN 'Family'
        WHEN b.guest_count > 5 THEN 'Group'
        ELSE 'Individual'
      END as gtype,
      COUNT(*) as count
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND b.check_in >= v_start AND b.check_in <= v_end
      AND (p_property_id IS NULL OR b.property_id = p_property_id)
    GROUP BY gtype
  ) gt;

  -- Units
  SELECT jsonb_object_agg(name, c) INTO v_bookings_by_unit
  FROM (
    SELECT p.name, COUNT(*) as c 
    FROM bookings b JOIN properties p ON b.property_id = p.id
    WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND b.check_in >= v_start AND b.check_in <= v_end
      AND (p_property_id IS NULL OR b.property_id = p_property_id)
    GROUP BY p.name ORDER BY c DESC LIMIT 10
  ) u;
  
  -- Sources
  SELECT 
    COUNT(*) FILTER (WHERE b.external_booking_id IS NULL),
    COUNT(*) FILTER (WHERE b.external_booking_id IS NOT NULL)
  INTO v_app_bookings, v_ical_bookings
  FROM bookings b JOIN properties p ON b.property_id = p.id
  WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND b.check_in >= v_start AND b.check_in <= v_end
    AND (p_property_id IS NULL OR b.property_id = p_property_id);

  v_bookings_by_source := jsonb_build_object('app_bookings', v_app_bookings, 'ical_bookings', v_ical_bookings);

  -- Monthly Revenue Breakdown
  SELECT jsonb_object_agg(to_char(month_date, 'Mon'), revenue) INTO v_revenue_by_month
  FROM (
    SELECT 
      DATE_TRUNC('month', b.check_in) as month_date, 
      SUM(
        CASE 
          WHEN b.total_price > 0 THEN b.total_price 
          ELSE (b.nights * COALESCE(NULLIF(p.price_per_night, 0), 150)) 
        END
      ) as revenue
    FROM bookings b JOIN properties p ON b.property_id = p.id
    WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND b.check_in >= v_start AND b.check_in <= v_end
      AND (p_property_id IS NULL OR b.property_id = p_property_id)
    GROUP BY 1 ORDER BY 1
  ) m;

  -- Expenses by Category
  SELECT jsonb_object_agg(category, total) INTO v_expenses_by_category
  FROM (
    SELECT e.category, SUM(e.amount) as total 
    FROM expenses e JOIN properties p ON e.property_id = p.id 
    WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND e.expense_date BETWEEN v_start AND v_end 
      AND (p_property_id IS NULL OR e.property_id = p_property_id)
    GROUP BY 1
  ) ec;

  -- Expenses by Property
  SELECT jsonb_object_agg(name, total) INTO v_expenses_by_property
  FROM (
    SELECT p.name, COALESCE(SUM(e.amount), 0) as total 
    FROM properties p LEFT JOIN expenses e ON e.property_id = p.id AND e.expense_date BETWEEN v_start AND v_end 
    WHERE (
      p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND (p_property_id IS NULL OR p.id = p_property_id)
    GROUP BY 1
  ) ep;

  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_expenses', v_total_expenses,
    'total_management_fees', v_total_management_fees,
    'landlord_share', v_landlord_share,
    'total_bookings', v_total_bookings,
    'occupancy_rate', ROUND(v_occupancy_rate, 1),
    'avg_rating', ROUND(v_avg_rating, 1),
    'revenue_by_month', COALESCE(v_revenue_by_month, '{}'::jsonb),
    'expenses_by_category', COALESCE(v_expenses_by_category, '{}'::jsonb),
    'expenses_by_property', COALESCE(v_expenses_by_property, '{}'::jsonb),
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
    'bookings_by_guest_type', COALESCE(v_bookings_by_guest_type, '{}'::jsonb),
    'bookings_by_unit', COALESCE(v_bookings_by_unit, '{}'::jsonb),
    'bookings_by_source', v_bookings_by_source,
    'total_booked_nights', v_total_booked_nights
  );
END;
$$;

-- 7. Test Assignment (Assign landlord@hostifystays.com)
INSERT INTO public.property_landlords (property_id, user_id)
SELECT p.id, u.id
FROM properties p, user_profiles u
WHERE (p.name LIKE '%Amazing 5 master suite%')
  AND u.email = 'landlord@hostifystays.com'
ON CONFLICT DO NOTHING;
