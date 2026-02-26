-- 1. Create Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL, -- 'booking_request', 'booking_update', 'system'
  data JSONB, -- Additional data (e.g. {booking_id: ...})
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 2. RLS Policies
CREATE POLICY "Users can view their own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications (mark as read)"
ON notifications FOR UPDATE
USING (auth.uid() = user_id);

-- 3. Database Triggers for Automatic Notifications

-- Function to notify landlord on new booking
CREATE OR REPLACE FUNCTION notify_landlord_on_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_landlord_id UUID;
    v_property_name TEXT;
    v_guest_name TEXT;
BEGIN
    -- Get Property Owner
    SELECT landlord_id, name INTO v_landlord_id, v_property_name
    FROM properties 
    WHERE id = NEW.property_id;

    -- Get Guest Name (if internal)
    IF NEW.guest_id IS NOT NULL THEN
        SELECT full_name INTO v_guest_name FROM user_profiles WHERE id = NEW.guest_id;
    ELSE
        v_guest_name := 'External Guest';
    END IF;

    -- Insert Notification for Landlord
    IF v_landlord_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, title, body, type, data)
        VALUES (
            v_landlord_id, 
            'New Booking Request', 
            'You have a new booking request for ' || v_property_name || ' from ' || COALESCE(v_guest_name, 'a guest'), 
            'booking_request', 
            jsonb_build_object('booking_id', NEW.id, 'property_id', NEW.property_id)
        );
    END IF;

    -- Also notify Managers (if any)
    INSERT INTO notifications (user_id, title, body, type, data)
    SELECT 
        user_id,
        'New Booking Request', 
        'New booking request for managed property ' || v_property_name,
        'booking_request',
        jsonb_build_object('booking_id', NEW.id, 'property_id', NEW.property_id)
    FROM property_managers
    WHERE property_id = NEW.property_id;

    RETURN NEW;
END;
$$;

-- Trigger: After Insert on Bookings
DROP TRIGGER IF EXISTS on_booking_created ON bookings;
CREATE TRIGGER on_booking_created
AFTER INSERT ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_landlord_on_booking();


-- Function to notify guest on status change
CREATE OR REPLACE FUNCTION notify_guest_on_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_property_name TEXT;
BEGIN
    IF OLD.status <> NEW.status AND NEW.guest_id IS NOT NULL THEN
        SELECT name INTO v_property_name FROM properties WHERE id = NEW.property_id;

        INSERT INTO notifications (user_id, title, body, type, data)
        VALUES (
            NEW.guest_id, 
            'Booking Update', 
            'Your booking for ' || v_property_name || ' has been ' || UPPER(NEW.status), 
            'booking_update', 
            jsonb_build_object('booking_id', NEW.id)
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Trigger: After Update on Bookings
DROP TRIGGER IF EXISTS on_booking_status_change ON bookings;
CREATE TRIGGER on_booking_status_change
AFTER UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_guest_on_status_change();
