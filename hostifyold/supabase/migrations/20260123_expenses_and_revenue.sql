-- Expenses and Revenue Sharing System

-- 1. Create expenses table
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  amount DECIMAL(12, 2) NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'cleaning', 'maintenance', 'problem', 'enhancement', 
    'plumbing', 'electricity', 'door', 'floor', 'wall', 
    'decoration', 'room', 'other'
  )),
  description TEXT,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create property_settings table for management fees
CREATE TABLE IF NOT EXISTS property_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID UNIQUE REFERENCES properties(id) ON DELETE CASCADE,
  management_fee_percentage DECIMAL(5, 2) DEFAULT 10.00,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS on expenses
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for expenses
DROP POLICY IF EXISTS "Admins can manage all expenses" ON expenses;
CREATE POLICY "Admins can manage all expenses" 
ON expenses FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
    AND user_roles.is_active = true
  )
);

DROP POLICY IF EXISTS "Landlords can view their property expenses" ON expenses;
CREATE POLICY "Landlords can view their property expenses" 
ON expenses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = expenses.property_id
    AND p.landlord_id = auth.uid()
  )
);

-- 5. Enable RLS on property_settings
ALTER TABLE property_settings ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for property_settings
DROP POLICY IF EXISTS "Admins can manage property settings" ON property_settings;
CREATE POLICY "Admins can manage property settings" 
ON property_settings FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
    AND user_roles.is_active = true
  )
);

DROP POLICY IF EXISTS "Landlords can view their property settings" ON property_settings;
CREATE POLICY "Landlords can view their property settings" 
ON property_settings FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = property_settings.property_id
    AND p.landlord_id = auth.uid()
  )
);

-- 7. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_expenses_property_id ON expenses(property_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);

-- 8. Enhanced analytics function with expenses and landlord share
CREATE OR REPLACE FUNCTION get_landlord_analytics_with_expenses(
  p_landlord_id UUID,
  p_start_date DATE DEFAULT DATE_TRUNC('year', CURRENT_DATE)::DATE,
  p_end_date DATE DEFAULT DATE_TRUNC('year', CURRENT_DATE)::DATE + INTERVAL '1 year' - INTERVAL '1 day'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
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
  v_property_ratings JSONB;
  v_property_revenues JSONB;
  v_most_booked_property TEXT;
  v_most_booked_count INTEGER := 0;
  v_app_bookings INTEGER := 0;
  v_ical_bookings INTEGER := 0;  
  v_total_days INTEGER;
  v_property_count INTEGER;
BEGIN
  -- Validate dates
  IF p_start_date IS NULL THEN p_start_date := DATE_TRUNC('year', CURRENT_DATE)::DATE; END IF;
  IF p_end_date IS NULL THEN p_end_date := DATE_TRUNC('year', CURRENT_DATE)::DATE + INTERVAL '1 year' - INTERVAL '1 day'; END IF;
  
  v_total_days := (p_end_date - p_start_date) + 1;
  IF v_total_days <= 0 THEN v_total_days := 1; END IF;

  -- Get Property Count
  SELECT COUNT(*) INTO v_property_count 
  FROM properties 
  WHERE landlord_id = p_landlord_id AND status = 'active';

  -- Calculate Total Revenue and Booked Nights from both app and iCalendar
  SELECT 
    COALESCE(SUM(total_price), 0),
    COUNT(*),
    COALESCE(SUM(nights), 0)
  INTO v_total_revenue, v_total_bookings, v_total_booked_nights
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date;

  -- Calculate Total Expenses for the period
  SELECT COALESCE(SUM(amount), 0)
  INTO v_total_expenses
  FROM expenses e
  JOIN properties p ON e.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND e.expense_date >= p_start_date AND e.expense_date <= p_end_date;

  -- Calculate Management Fees (percentage of revenue per property)
  SELECT COALESCE(SUM(property_revenue * COALESCE(ps.management_fee_percentage, 10.00) / 100), 0)
  INTO v_total_management_fees
  FROM (
    SELECT 
      p.id as property_id,
      COALESCE(SUM(b.total_price), 0) as property_revenue
    FROM properties p
    LEFT JOIN bookings b ON b.property_id = p.id 
      AND b.status IN ('confirmed', 'completed', 'active')
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    WHERE p.landlord_id = p_landlord_id AND p.status = 'active'
    GROUP BY p.id
  ) rev
  LEFT JOIN property_settings ps ON ps.property_id = rev.property_id;

  -- Calculate Landlord Share
  v_landlord_share := v_total_revenue - v_total_expenses - v_total_management_fees;

  -- Average Rating
  SELECT COALESCE(AVG(overall_rating), 0)
  INTO v_avg_rating
  FROM reviews r
  JOIN properties p ON r.property_id = p.id
  WHERE p.landlord_id = p_landlord_id;

  -- Occupancy Rate
  IF v_property_count > 0 THEN
    v_occupancy_rate := COALESCE((v_total_booked_nights::DECIMAL / (v_property_count * v_total_days)) * 100, 0);
  END IF;

  -- Revenue by Month
  SELECT jsonb_object_agg(to_char(month_date, 'Mon'), revenue)
  INTO v_revenue_by_month
  FROM (
    SELECT 
      DATE_TRUNC('month', b.check_in) as month_date,
      SUM(b.total_price) as revenue
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.status IN ('confirmed', 'completed', 'active')
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY DATE_TRUNC('month', b.check_in)
    ORDER BY DATE_TRUNC('month', b.check_in)
  ) m;

  -- Expenses by Category
  SELECT jsonb_object_agg(category, total_amount)
  INTO v_expenses_by_category
  FROM (
    SELECT 
      e.category,
      SUM(e.amount) as total_amount
    FROM expenses e
    JOIN properties p ON e.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND e.expense_date >= p_start_date AND e.expense_date <= p_end_date
    GROUP BY e.category
  ) ec;

  -- Expenses by Property
  SELECT jsonb_object_agg(property_name, total_expense)
  INTO v_expenses_by_property
  FROM (
    SELECT 
      p.name as property_name,
      COALESCE(SUM(e.amount), 0) as total_expense
    FROM properties p
    LEFT JOIN expenses e ON e.property_id = p.id 
      AND e.expense_date >= p_start_date AND e.expense_date <= p_end_date
    WHERE p.landlord_id = p_landlord_id AND p.status = 'active'
    GROUP BY p.id, p.name
  ) ep;

  -- Property Revenues with Landlord Share per Property
  SELECT jsonb_object_agg(property_name, property_data)
  INTO v_property_revenues
  FROM (
    SELECT 
      p.name as property_name,
      jsonb_build_object(
        'revenue', COALESCE(SUM(b.total_price), 0),
        'booked_nights', COALESCE(SUM(b.nights), 0),
        'expenses', COALESCE(
          (SELECT SUM(amount) FROM expenses WHERE property_id = p.id 
           AND expense_date >= p_start_date AND expense_date <= p_end_date), 0
        ),
        'management_fee_pct', COALESCE(ps.management_fee_percentage, 10.00),
        'management_fee_amount', COALESCE(SUM(b.total_price), 0) * COALESCE(ps.management_fee_percentage, 10.00) / 100,
        'landlord_share', COALESCE(SUM(b.total_price), 0) - 
          COALESCE((SELECT SUM(amount) FROM expenses WHERE property_id = p.id 
                    AND expense_date >= p_start_date AND expense_date <= p_end_date), 0) -
          (COALESCE(SUM(b.total_price), 0) * COALESCE(ps.management_fee_percentage, 10.00) / 100)
      ) as property_data
    FROM properties p
    LEFT JOIN bookings b ON b.property_id = p.id 
      AND b.status IN ('confirmed', 'completed', 'active')
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    LEFT JOIN property_settings ps ON ps.property_id = p.id
    WHERE p.landlord_id = p_landlord_id AND p.status = 'active'
    GROUP BY p.id, p.name, ps.management_fee_percentage
  ) pr;

  -- Bookings by Unit
  SELECT jsonb_object_agg(name, booking_count)
  INTO v_bookings_by_unit
  FROM (
    SELECT 
      p.name,
      COUNT(*) as booking_count
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.status IN ('confirmed', 'completed', 'active')
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY p.name
    ORDER BY booking_count DESC
    LIMIT 10
  ) u;

  -- Most Booked Property
  SELECT p.name, COUNT(*) INTO v_most_booked_property, v_most_booked_count
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date
  GROUP BY p.id, p.name
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Bookings by Source
  SELECT 
    COUNT(*) FILTER (WHERE b.booking_source = 'hostify'),
    COUNT(*) FILTER (WHERE b.booking_source != 'hostify')
  INTO v_app_bookings, v_ical_bookings
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date;

  v_bookings_by_source := jsonb_build_object(
    'app_bookings', v_app_bookings,
    'ical_bookings', v_ical_bookings
  );

  -- Bookings by Nationality/Source
  SELECT jsonb_object_agg(COALESCE(nationality, 'Unknown'), count)
  INTO v_bookings_by_nationality
  FROM (
    SELECT 
      CASE 
        WHEN b.booking_source = 'airbnb' THEN 'Airbnb'
        WHEN b.booking_source = 'booking_com' THEN 'Booking.com'
        ELSE 'Hostify App' 
      END as nationality,
      COUNT(*) as count
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY nationality
  ) n;
  
  -- Bookings by Guest Type
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
    WHERE p.landlord_id = p_landlord_id
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY guest_type
  ) g;

  -- Property Ratings
  SELECT jsonb_object_agg(property_name, avg_rating)
  INTO v_property_ratings
  FROM (
    SELECT 
      p.name as property_name,
      ROUND(COALESCE(AVG(r.overall_rating), 0), 1) as avg_rating
    FROM properties p
    LEFT JOIN reviews r ON r.property_id = p.id
    WHERE p.landlord_id = p_landlord_id AND p.status = 'active'
    GROUP BY p.id, p.name
    ORDER BY avg_rating DESC
  ) pr;

  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_bookings', v_total_bookings,
    'total_booked_nights', v_total_booked_nights,
    'total_expenses', v_total_expenses,
    'total_management_fees', v_total_management_fees,
    'landlord_share', v_landlord_share,
    'occupancy_rate', ROUND(v_occupancy_rate, 1),
    'avg_rating', ROUND(v_avg_rating, 1),
    'revenue_by_month', COALESCE(v_revenue_by_month, '{}'::jsonb),
    'expenses_by_category', COALESCE(v_expenses_by_category, '{}'::jsonb),
    'expenses_by_property', COALESCE(v_expenses_by_property, '{}'::jsonb),
    'property_revenues', COALESCE(v_property_revenues, '{}'::jsonb),
    'bookings_by_unit', COALESCE(v_bookings_by_unit, '{}'::jsonb),
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
    'bookings_by_guest_type', COALESCE(v_bookings_by_guest_type, '{}'::jsonb),
    'bookings_by_source', v_bookings_by_source,
    'property_ratings', COALESCE(v_property_ratings, '{}'::jsonb),
    'most_booked_property', v_most_booked_property,
    'most_booked_count', v_most_booked_count,
    'app_bookings', v_app_bookings,
    'ical_bookings', v_ical_bookings
  );
END;
$$;
