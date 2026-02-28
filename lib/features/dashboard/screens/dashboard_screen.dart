import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/loading_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final upcomingAsync = ref.watch(upcomingBookingsProvider);
    final user = ref.watch(currentUserProvider);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(upcomingBookingsProvider);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good ${_greeting()}!',
                              style: Theme.of(context).textTheme.bodyMedium),
                          Text(
                            user?.displayName ?? 'Host',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.go('/settings'),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          backgroundColor: AppColors.primary,
                          child: user?.photoURL == null
                              ? Text(
                                  (user?.displayName ?? 'H')[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Grid
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Revenue',
                                value: currency.format(stats.monthlyRevenue),
                                subtitle: 'This month',
                                icon: Icons.trending_up_rounded,
                                iconColor: AppColors.success,
                                gradient: [
                                  AppColors.success.withOpacity(0.15),
                                  AppColors.bgCard,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Net Profit',
                                value: currency.format(stats.netProfit),
                                subtitle: 'This month',
                                icon: Icons.account_balance_wallet_outlined,
                                iconColor: AppColors.primary,
                                gradient: [
                                  AppColors.primary.withOpacity(0.15),
                                  AppColors.bgCard,
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Properties',
                                value: stats.totalProperties.toString(),
                                subtitle: 'Total active',
                                icon: Icons.home_rounded,
                                iconColor: AppColors.info,
                                gradient: [
                                  AppColors.info.withOpacity(0.15),
                                  AppColors.bgCard,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Bookings',
                                value: stats.activeBookings.toString(),
                                subtitle: 'Confirmed',
                                icon: Icons.calendar_month_rounded,
                                iconColor: AppColors.warning,
                                gradient: [
                                  AppColors.warning.withOpacity(0.15),
                                  AppColors.bgCard,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  loading: () => LoadingWidget(),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: $e',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ),
              ),

              // Upcoming Bookings
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upcoming Bookings',
                          style: Theme.of(context).textTheme.titleLarge),
                      TextButton(
                        onPressed: () => context.go('/bookings'),
                        child: const Text('See all',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ),

              upcomingAsync.when(
                data: (bookings) => bookings.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text('No upcoming bookings',
                                    style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final b = bookings[i];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: _BookingCard(booking: b),
                            );
                          },
                          childCount: bookings.length,
                        ),
                      ),
                loading: () =>
                    SliverToBoxAdapter(child: LoadingWidget()),
                error: (e, _) => SliverToBoxAdapter(
                  child: Text('$e',
                      style: const TextStyle(color: AppColors.error)),
                ),
              ),


              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _BookingCard extends StatelessWidget {
  final dynamic booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d');
    final statusColor = booking.status == 'confirmed'
        ? AppColors.success
        : booking.status == 'pending'
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.property?.name ?? 'Property',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.guest?.fullName ?? 'Guest'} · ${fmt.format(booking.checkIn)} – ${fmt.format(booking.checkOut)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              booking.status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
