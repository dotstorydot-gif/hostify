import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_config.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../shared/models/models.dart';

// ─── Properties ────────────────────────────────────────────────────────────

final propertiesProvider = FutureProvider<List<PropertyModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final data = await SupabaseConfig.client
      .from('properties')
      .select()
      .eq('owner_id', user.uid)
      .order('created_at', ascending: false);
  return (data as List).map((e) => PropertyModel.fromJson(e)).toList();
});

final propertyByIdProvider =
    FutureProvider.family<PropertyModel?, String>((ref, id) async {
  final data = await SupabaseConfig.client
      .from('properties')
      .select()
      .eq('id', id)
      .maybeSingle();
  if (data == null) return null;
  return PropertyModel.fromJson(data);
});

// ─── Guests ──────────────────────────────────────────────────────────────

final guestsProvider = FutureProvider<List<GuestModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final data = await SupabaseConfig.client
      .from('guests')
      .select()
      .eq('owner_id', user.uid)
      .order('full_name');
  return (data as List).map((e) => GuestModel.fromJson(e)).toList();
});

// ─── Bookings ──────────────────────────────────────────────────────────────

final bookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final data = await SupabaseConfig.client
      .from('bookings')
      .select('*, properties(*), guests(*)')
      .eq('owner_id', user.uid)
      .order('check_in', ascending: false);
  return (data as List).map((e) => BookingModel.fromJson(e)).toList();
});

final upcomingBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final today = DateTime.now().toIso8601String().split('T')[0];
  final data = await SupabaseConfig.client
      .from('bookings')
      .select('*, properties(*), guests(*)')
      .eq('owner_id', user.uid)
      .gte('check_in', today)
      .order('check_in')
      .limit(5);
  return (data as List).map((e) => BookingModel.fromJson(e)).toList();
});

// ─── Expenses ──────────────────────────────────────────────────────────────

final expensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final data = await SupabaseConfig.client
      .from('expenses')
      .select()
      .eq('owner_id', user.uid)
      .order('date', ascending: false);
  return (data as List).map((e) => ExpenseModel.fromJson(e)).toList();
});

// ─── Dashboard Stats ───────────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final bookings = await ref.watch(bookingsProvider.future);
  final expenses = await ref.watch(expensesProvider.future);
  final properties = await ref.watch(propertiesProvider.future);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final monthlyRevenue = bookings
      .where((b) =>
          b.createdAt.isAfter(monthStart) && b.status != 'cancelled')
      .fold(0.0, (sum, b) => sum + b.totalPrice);

  final monthlyExpenses = expenses
      .where((e) => e.date.isAfter(monthStart))
      .fold(0.0, (sum, e) => sum + e.amount);

  final activeBookings =
      bookings.where((b) => b.status == 'confirmed').length;

  return DashboardStats(
    totalProperties: properties.length,
    activeBookings: activeBookings,
    monthlyRevenue: monthlyRevenue,
    monthlyExpenses: monthlyExpenses,
    netProfit: monthlyRevenue - monthlyExpenses,
  );
});

class DashboardStats {
  final int totalProperties;
  final int activeBookings;
  final double monthlyRevenue;
  final double monthlyExpenses;
  final double netProfit;

  const DashboardStats({
    required this.totalProperties,
    required this.activeBookings,
    required this.monthlyRevenue,
    required this.monthlyExpenses,
    required this.netProfit,
  });
}
