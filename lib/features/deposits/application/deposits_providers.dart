import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/appointment.dart';
import '../../business_context/application/active_business_provider.dart';

final pendingDepositsProvider = FutureProvider.autoDispose<List<Appointment>>(
  (ref) async {
    final membership = await ref.watch(activeMembershipProvider.future);
    if (membership == null) return [];
    final client = ref.watch(supabaseClientProvider);
    try {
      final data = await client
          .from('appointments')
          .select(appointmentSelectColumns)
          .eq('business_id', membership.business.id)
          .eq('deposit_status', 'PENDING')
          .order('start_time', ascending: true);
      return (data as List)
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  },
);
