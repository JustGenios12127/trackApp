import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountTasks {
  Future<int> openCount();
}

class SupabaseAccountTasks implements AccountTasks {
  const SupabaseAccountTasks();

  @override
  Future<int> openCount() async {
    final rows = await Supabase.instance.client
        .from('tasks')
        .select('id')
        .eq('status', 'open');
    return rows.length;
  }
}
