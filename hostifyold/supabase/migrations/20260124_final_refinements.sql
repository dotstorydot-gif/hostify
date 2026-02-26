-- Final Refinements Migration

-- 1. Update get_my_properties to allow Admins to see everything
CREATE OR REPLACE FUNCTION get_my_properties(p_user_id UUID)
RETURNS SETOF properties
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If user is admin, return ALL properties
  IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role = 'admin' AND is_active = true) THEN
    RETURN QUERY SELECT * FROM properties ORDER BY created_at DESC;
  ELSE
    -- For others, return owned or assigned properties
    RETURN QUERY 
    SELECT * FROM properties p
    WHERE p.landlord_id = p_user_id
       OR EXISTS (
         SELECT 1 FROM property_landlords pl 
         WHERE pl.property_id = p.id AND pl.user_id = p_user_id
       )
    ORDER BY created_at DESC;
  END IF;
END;
$$;

-- 2. Update get_landlord_analytics_with_expenses to support Global Admin View and 15% Fee Default
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
  v_is_admin BOOLEAN;
BEGIN
  v_total_days := (v_end - v_start) + 1;
  IF v_total_days <= 0 THEN v_total_days := 1; END IF;

  -- Check if caller is admin
  SELECT EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_landlord_id AND role = 'admin' AND is_active = true) INTO v_is_admin;

  -- Property Count
  SELECT COUNT(*) INTO v_property_count 
  FROM properties p
  WHERE (
      v_is_admin 
      OR p.landlord_id = p_landlord_id 
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
      v_is_admin
      OR p.landlord_id = p_landlord_id 
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
      v_is_admin
      OR p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND e.expense_date >= v_start AND e.expense_date <= v_end
    AND (p_property_id IS NULL OR e.property_id = p_property_id);

  -- Management Fees (Always 15% default)
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
      v_is_admin
      OR p.landlord_id = p_landlord_id 
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
      v_is_admin
      OR p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND (p_property_id IS NULL OR p.id = p_property_id);

  -- Nationality Split (Detailed for Dashboard)
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
      v_is_admin
      OR p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
      AND b.check_in >= v_start AND b.check_in <= v_end
      AND (p_property_id IS NULL OR b.property_id = p_property_id)
    GROUP BY nat
  ) n;

  -- Sources Split
  SELECT 
    COUNT(*) FILTER (WHERE b.external_booking_id IS NULL),
    COUNT(*) FILTER (WHERE b.external_booking_id IS NOT NULL)
  INTO v_app_bookings, v_ical_bookings
  FROM bookings b JOIN properties p ON b.property_id = p.id
  WHERE (
      v_is_admin
      OR p.landlord_id = p_landlord_id 
      OR EXISTS (SELECT 1 FROM property_landlords pl WHERE pl.property_id = p.id AND pl.user_id = p_landlord_id)
    )
    AND b.check_in >= v_start AND b.check_in <= v_end
    AND (p_property_id IS NULL OR b.property_id = p_property_id);

  v_bookings_by_source := jsonb_build_object('app_bookings', v_app_bookings, 'ical_bookings', v_ical_bookings);

  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_expenses', v_total_expenses,
    'total_management_fees', v_total_management_fees,
    'landlord_share', v_landlord_share,
    'total_bookings', v_total_bookings,
    'occupancy_rate', ROUND(v_occupancy_rate, 1),
    'avg_rating', ROUND(v_avg_rating, 1),
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
    'bookings_by_source', v_bookings_by_source,
    'total_booked_nights', v_total_booked_nights
  );
END;
$$;
