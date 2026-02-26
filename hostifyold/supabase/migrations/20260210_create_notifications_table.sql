-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'booking', 'service', 'system'
    is_read BOOLEAN DEFAULT FALSE,
    related_id UUID, -- reference to booking_id or service_request_id
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- Admin Policy (Admins can see all? Usually yes, but here let's keep it simple or add role check)
-- For now, let's allow service role or specific roles if needed.

-- Function to notify admins on new booking
CREATE OR REPLACE FUNCTION public.notify_admin_on_booking()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, related_id)
    SELECT id, 'New Booking', 'A new booking has been created.', 'booking', NEW.id
    FROM public.user_roles
    WHERE role = 'admin';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new booking
CREATE TRIGGER on_booking_created
    AFTER INSERT ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.notify_admin_on_booking();

-- Function to notify admins on new service request
CREATE OR REPLACE FUNCTION public.notify_admin_on_service_request()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, related_id)
    SELECT id, 'New Service Request', 'A new ' || NEW.category || ' request has been submitted.', 'service', NEW.id
    FROM public.user_roles
    WHERE role = 'admin';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new service request
CREATE TRIGGER on_service_request_created
    AFTER INSERT ON public.service_requests
    FOR EACH ROW EXECUTE FUNCTION public.notify_admin_on_service_request();

-- Function to notify guest on status update (booking or service)
-- This is slightly more complex as it depends on updates.
