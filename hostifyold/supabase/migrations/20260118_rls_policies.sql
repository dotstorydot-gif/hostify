-- ============================================
-- .Hostify - Row Level Security Policies
-- Version: 1.0.0
-- Description: RLS policies for all tables
-- ============================================

-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.icalendar_feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_financials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- ============================================
-- HELPER FUNCTION: Check if user has role
-- ============================================

CREATE OR REPLACE FUNCTION public.user_has_role(check_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
    AND role = check_role
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- USER_PROFILES POLICIES
-- ============================================

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON public.user_profiles FOR SELECT
  USING (public.user_has_role('admin'));

CREATE POLICY "Admins can manage all profiles"
  ON public.user_profiles FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- USER_ROLES POLICIES
-- ============================================

CREATE POLICY "Users can view own roles"
  ON public.user_roles FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own roles"
  ON public.user_roles FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage all roles"
  ON public.user_roles FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- GUEST_DOCUMENTS POLICIES
-- ============================================

CREATE POLICY "Guests can view own documents"
  ON public.guest_documents FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Guests can insert own documents"
  ON public.guest_documents FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Guests can update own documents"
  ON public.guest_documents FOR UPDATE
  USING (user_id = auth.uid() AND verification_status = 'pending');

CREATE POLICY "Admins can manage all documents"
  ON public.guest_documents FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- PROPERTIES POLICIES
-- ============================================

CREATE POLICY "Everyone can view active properties"
  ON public.properties FOR SELECT
  USING (status = 'active' OR landlord_id = auth.uid() OR public.user_has_role('admin'));

CREATE POLICY "Landlords can insert own properties"
  ON public.properties FOR INSERT
  WITH CHECK (landlord_id = auth.uid() AND public.user_has_role('landlord'));

CREATE POLICY "Landlords can update own properties"
  ON public.properties FOR UPDATE
  USING (landlord_id = auth.uid());

CREATE POLICY "Landlords can delete own properties"
  ON public.properties FOR DELETE
  USING (landlord_id = auth.uid());

CREATE POLICY "Admins can manage all properties"
  ON public.properties FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- PROPERTY_IMAGES POLICIES
-- ============================================

CREATE POLICY "Everyone can view property images"
  ON public.property_images FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id
      AND (status = 'active' OR landlord_id = auth.uid() OR public.user_has_role('admin'))
    )
  );

CREATE POLICY "Landlords can manage own property images"
  ON public.property_images FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all property images"
  ON public.property_images FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- PROPERTY_AMENITIES POLICIES
-- ============================================

CREATE POLICY "Everyone can view property amenities"
  ON public.property_amenities FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id
      AND (status = 'active' OR landlord_id = auth.uid() OR public.user_has_role('admin'))
    )
  );

CREATE POLICY "Landlords can manage own property amenities"
  ON public.property_amenities FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all property amenities"
  ON public.property_amenities FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- BOOKINGS POLICIES
-- ============================================

CREATE POLICY "Guests can view own bookings"
  ON public.bookings FOR SELECT
  USING (guest_id = auth.uid());

CREATE POLICY "Guests can create bookings"
  ON public.bookings FOR INSERT
  WITH CHECK (guest_id = auth.uid() AND public.user_has_role('guest'));

CREATE POLICY "Landlords can view property bookings"
  ON public.bookings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all bookings"
  ON public.bookings FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- ICALENDAR_FEEDS POLICIES
-- ============================================

CREATE POLICY "Landlords can view own ical feeds"
  ON public.icalendar_feeds FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Landlords can manage own ical feeds"
  ON public.icalendar_feeds FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all ical feeds"
  ON public.icalendar_feeds FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- REVIEWS POLICIES
-- ============================================

CREATE POLICY "Everyone can view published reviews"
  ON public.reviews FOR SELECT
  USING (status = 'published' OR guest_id = auth.uid() OR public.user_has_role('admin'));

CREATE POLICY "Guests can create reviews for own bookings"
  ON public.reviews FOR INSERT
  WITH CHECK (
    guest_id = auth.uid() 
    AND public.user_has_role('guest')
    AND EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id
      AND guest_id = auth.uid()
      AND status = 'completed'
    )
  );

CREATE POLICY "Guests can update own reviews"
  ON public.reviews FOR UPDATE
  USING (guest_id = auth.uid());

CREATE POLICY "Admins can manage all reviews"
  ON public.reviews FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- REVIEW_IMAGES POLICIES
-- ============================================

CREATE POLICY "Everyone can view published review images"
  ON public.review_images FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.reviews
      WHERE id = review_id
      AND (status = 'published' OR guest_id = auth.uid() OR public.user_has_role('admin'))
    )
  );

CREATE POLICY "Guests can manage own review images"
  ON public.review_images FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.reviews
      WHERE id = review_id AND guest_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all review images"
  ON public.review_images FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- SERVICE_REQUESTS POLICIES
-- ============================================

CREATE POLICY "Guests can view own service requests"
  ON public.service_requests FOR SELECT
  USING (guest_id = auth.uid());

CREATE POLICY "Guests can create service requests"
  ON public.service_requests FOR INSERT
  WITH CHECK (
    guest_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id
      AND guest_id = auth.uid()
      AND status IN ('confirmed', 'active')
    )
  );

CREATE POLICY "Landlords can view property service requests"
  ON public.service_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all service requests"
  ON public.service_requests FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- PROPERTY_FINANCIALS POLICIES
-- ============================================

CREATE POLICY "Landlords can view own property financials"
  ON public.property_financials FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all financials"
  ON public.property_financials FOR ALL
  USING (public.user_has_role('admin'));

-- ============================================
-- EXPENSES POLICIES
-- ============================================

CREATE POLICY "Landlords can view own property expenses"
  ON public.expenses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Landlords can manage own property expenses"
  ON public.expenses FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.properties
      WHERE id = property_id AND landlord_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all expenses"
  ON public.expenses FOR ALL
  USING (public.user_has_role('admin'));
