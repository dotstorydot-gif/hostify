-- ============================================
-- .Hostify - Supabase Database Migration
-- Version: 1.0.0
-- Description: Initial schema with multi-role auth
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 1. USER MANAGEMENT
-- ============================================

-- User Profiles Table
CREATE TABLE public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone TEXT,
  profile_photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Roles Junction Table (allows multiple roles per user)
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('guest', 'landlord', 'admin', 'traveler')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- Guest Documents Table
CREATE TABLE public.guest_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN ('passport', 'id')),
  front_image_url TEXT NOT NULL,
  back_image_url TEXT,
  verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES public.user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. PROPERTY MANAGEMENT
-- ============================================

-- Properties Table
CREATE TABLE public.properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  landlord_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  location TEXT NOT NULL,
  address TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  property_type TEXT CHECK (property_type IN ('villa', 'apartment', 'house', 'studio')),
  bedrooms INTEGER DEFAULT 1,
  bathrooms INTEGER DEFAULT 1,
  max_guests INTEGER DEFAULT 2,
  price_per_night DECIMAL(10, 2) NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Property Images Table
CREATE TABLE public.property_images (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Property Amenities Table
CREATE TABLE public.property_amenities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  amenity TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. BOOKING SYSTEM
-- ============================================

-- Bookings Table
CREATE TABLE public.bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id),
  guest_id UUID NOT NULL REFERENCES public.user_profiles(id),
  unit_name TEXT,
  room_number TEXT,
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  nights INTEGER NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'active', 'completed', 'cancelled')),
  booking_source TEXT DEFAULT 'hostify' CHECK (booking_source IN ('hostify', 'booking_com', 'airbnb')),
  external_booking_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- iCalendar Feeds Table
CREATE TABLE public.icalendar_feeds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('booking_com', 'airbnb')),
  feed_url TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  last_synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(property_id, platform)
);

-- ============================================
-- 4. REVIEWS & RATINGS
-- ============================================

-- Reviews Table
CREATE TABLE public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES public.bookings(id),
  guest_id UUID NOT NULL REFERENCES public.user_profiles(id),
  guest_name TEXT NOT NULL,
  overall_rating DECIMAL(2, 1) CHECK (overall_rating >= 1.0 AND overall_rating <= 5.0),
  cleanliness_rating DECIMAL(2, 1) CHECK (cleanliness_rating >= 1.0 AND cleanliness_rating <= 5.0),
  location_rating DECIMAL(2, 1) CHECK (location_rating >= 1.0 AND location_rating <= 5.0),
  value_rating DECIMAL(2, 1) CHECK (value_rating >= 1.0 AND value_rating <= 5.0),
  amenities_rating DECIMAL(2, 1) CHECK (amenities_rating >= 1.0 AND amenities_rating <= 5.0),
  service_rating DECIMAL(2, 1) CHECK (service_rating >= 1.0 AND service_rating <= 5.0),
  accuracy_rating DECIMAL(2, 1) CHECK (accuracy_rating >= 1.0 AND accuracy_rating <= 5.0),
  review_text TEXT,
  status TEXT DEFAULT 'published' CHECK (status IN ('pending', 'published', 'hidden')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Review Images Table
CREATE TABLE public.review_images (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 5. SERVICE REQUESTS
-- ============================================

-- Service Requests Table
CREATE TABLE public.service_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id),
  guest_id UUID NOT NULL REFERENCES public.user_profiles(id),
  property_id UUID NOT NULL REFERENCES public.properties(id),
  category TEXT NOT NULL CHECK (category IN ('concierge', 'excursions', 'room_service')),
  service_type TEXT NOT NULL,
  details TEXT,
  preferred_time TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  notes TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 6. FINANCIAL MANAGEMENT
-- ============================================

-- Property Financials Table
CREATE TABLE public.property_financials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  period_year INTEGER NOT NULL,
  period_month INTEGER CHECK (period_month BETWEEN 1 AND 12),
  total_revenue DECIMAL(12, 2) DEFAULT 0,
  nights_booked INTEGER DEFAULT 0,
  management_fee_percentage DECIMAL(5, 2) DEFAULT 15.00,
  management_fee_amount DECIMAL(12, 2) DEFAULT 0,
  landlord_share DECIMAL(12, 2) DEFAULT 0,
  net_profit DECIMAL(12, 2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(property_id, period_year, period_month)
);

-- Expenses Table
CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  cost DECIMAL(10, 2) NOT NULL,
  category TEXT CHECK (category IN ('cleaning', 'maintenance', 'utilities', 'supplies', 'other')),
  expense_date DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_user_roles_active ON public.user_roles(user_id, role) WHERE is_active = true;
CREATE INDEX idx_properties_landlord ON public.properties(landlord_id);
CREATE INDEX idx_properties_status ON public.properties(status);
CREATE INDEX idx_bookings_property ON public.bookings(property_id);
CREATE INDEX idx_bookings_guest ON public.bookings(guest_id);
CREATE INDEX idx_bookings_dates ON public.bookings(check_in, check_out);
CREATE INDEX idx_bookings_status ON public.bookings(status);
CREATE INDEX idx_reviews_property ON public.reviews(property_id);
CREATE INDEX idx_reviews_status ON public.reviews(status);
CREATE INDEX idx_service_requests_booking ON public.service_requests(booking_id);
CREATE INDEX idx_service_requests_status ON public.service_requests(status);
CREATE INDEX idx_expenses_property ON public.expenses(property_id);

-- ============================================
-- TRIGGERS & FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to all tables with updated_at
CREATE TRIGGER set_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_guest_documents_updated_at
  BEFORE UPDATE ON public.guest_documents
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_properties_updated_at
  BEFORE UPDATE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_icalendar_feeds_updated_at
  BEFORE UPDATE ON public.icalendar_feeds
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_reviews_updated_at
  BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_service_requests_updated_at
  BEFORE UPDATE ON public.service_requests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_property_financials_updated_at
  BEFORE UPDATE ON public.property_financials
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_expenses_updated_at
  BEFORE UPDATE ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Function to calculate property financials
CREATE OR REPLACE FUNCTION public.calculate_property_financials()
RETURNS TRIGGER AS $$
BEGIN
  NEW.management_fee_amount := NEW.total_revenue * (NEW.management_fee_percentage / 100);
  NEW.landlord_share := NEW.total_revenue - NEW.management_fee_amount;
  
  -- Calculate net profit (landlord share minus expenses)
  NEW.net_profit := NEW.landlord_share - (
    SELECT COALESCE(SUM(cost), 0)
    FROM public.expenses
    WHERE property_id = NEW.property_id
    AND EXTRACT(YEAR FROM expense_date) = NEW.period_year
    AND (NEW.period_month IS NULL OR EXTRACT(MONTH FROM expense_date) = NEW.period_month)
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_financials
  BEFORE INSERT OR UPDATE ON public.property_financials
  FOR EACH ROW EXECUTE FUNCTION public.calculate_property_financials();

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
