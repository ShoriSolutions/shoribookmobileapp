import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/deposit_payment_details.dart';
import '../data/deposit_flow_repository.dart';

final depositFlowRepositoryProvider = Provider<DepositFlowRepository>((ref) {
  return DepositFlowRepository(ref.watch(supabaseClientProvider));
});

typedef DepositDetailsArgs = ({String appointmentId, String? guestPhone});

final depositPaymentDetailsProvider = FutureProvider.autoDispose
    .family<DepositPaymentDetails, DepositDetailsArgs>((ref, args) async {
  return ref.watch(depositFlowRepositoryProvider).getPaymentDetails(
        args.appointmentId,
        guestPhone: args.guestPhone,
      );
});
