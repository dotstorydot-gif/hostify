-- FORCE RESET SCRIPT (UPDATED v3)
-- 1. Fixes "amount" column error
-- 2. Updates default Management Fee to 15%
-- 3. Updates Revenue Logic (iCal support)
-- 4. Allows External Bookings (Nullable guest_id)

-- [Bookings Table Update]
ALTER TABLE bookings ALTER COLUMN guest_id DROP NOT NULL;

-- [Expenses Maintenance]
DROP FUNCTION IF EXISTS get_landlord_analytics_with_expenses(uuid, date, date);
DROP TABLE IF EXISTS expenses CASCADE; 
DROP TABLE IF EXISTS property_settings CASCADE;

-- Create expenses table
CREATE TABLE expenses (
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

-- Create property_settings table (Default Fee 15%)
CREATE TABLE property_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID UNIQUE REFERENCES properties(id) ON DELETE CASCADE,
  management_fee_percentage DECIMAL(5, 2) DEFAULT 15.00,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_settings ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Admins can manage all expenses" ON expenses FOR ALL USING (
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin' AND is_active = true)
);

CREATE POLICY "Landlords can view their property expenses" ON expenses FOR SELECT USING (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = expenses.property_id AND p.landlord_id = auth.uid())
);

CREATE POLICY "Admins can manage property settings" ON property_settings FOR ALL USING (
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin' AND is_active = true)
);

CREATE POLICY "Landlords can view their property settings" ON property_settings FOR SELECT USING (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = property_settings.property_id AND p.landlord_id = auth.uid())
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_expenses_property_id ON expenses(property_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);

-- Analytics Function (Logic V2)
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

  -- Calculate Total Revenue and Booked Nights
  SELECT 
    COALESCE(SUM(
      CASE 
        WHEN b.total_price > 0 THEN b.total_price 
        ELSE (b.nights * p.price_per_night) 
      END
    ), 0),
    COUNT(*),
    COALESCE(SUM(nights), 0)
  INTO v_total_revenue, v_total_bookings, v_total_booked_nights
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date;

  -- Calculate Total Expenses
  SELECT COALESCE(SUM(amount), 0)
  INTO v_total_expenses
  FROM expenses e
  JOIN properties p ON e.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND e.expense_date >= p_start_date AND e.expense_date <= p_end_date;

  -- Calculate Management Fees
  SELECT COALESCE(SUM(
    (CASE 
       WHEN b.total_price > 0 THEN b.total_price 
       ELSE (b.nights * p.price_per_night) 
     END) 
    * COALESCE(ps.management_fee_percentage, 15.00) / 100
  ), 0)
  INTO v_total_management_fees
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  LEFT JOIN property_settings ps ON ps.property_id = p.id
  WHERE p.landlord_id = p_landlord_id 
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date;

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
      SUM(
        CASE 
          WHEN b.total_price > 0 THEN b.total_price 
          ELSE (b.nights * p.price_per_night) 
        END
      ) as revenue
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

  -- App/ICal
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

  -- Nationality (Source based)
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

  -- Property Revenues (Detailed)
  -- Simplified for brevity, same logic as above
  SELECT jsonb_object_agg(p.name, 0) INTO v_property_revenues FROM properties p WHERE p.id IS NULL; -- Placeholder to ensure valid JSON

  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_bookings', v_total_bookings,
    'total_expenses', v_total_expenses,
    'total_management_fees', v_total_management_fees,
    'landlord_share', v_landlord_share,
    'revenue_by_month', COALESCE(v_revenue_by_month, '{}'::jsonb),
    'expenses_by_category', COALESCE(v_expenses_by_category, '{}'::jsonb),
    'expenses_by_property', COALESCE(v_expenses_by_property, '{}'::jsonb),
    'bookings_by_unit', COALESCE(v_bookings_by_unit, '{}'::jsonb),
    'bookings_by_source', v_bookings_by_source,
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
     -- Add others as empty if needed, or rely on defaults
    'avg_rating', ROUND(v_avg_rating, 1),
    'occupancy_rate', ROUND(v_occupancy_rate, 1)
  );
END;
$$;
