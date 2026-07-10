import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/appointments_repository.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((
  ref,
) {
  return AppointmentsRepository(ref.watch(supabaseClientProvider));
});
