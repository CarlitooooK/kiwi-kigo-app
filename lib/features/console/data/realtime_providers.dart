import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_provider.dart';

/// Real-time visit updates for the console.
/// 
/// Subscribes to INSERT and UPDATE events on the visits table.
/// Console screens can watch this provider to get live updates.
class VisitRealtimeEvent {
  final String eventType; // INSERT, UPDATE, DELETE
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic>? oldRecord;

  const VisitRealtimeEvent({
    required this.eventType,
    required this.newRecord,
    this.oldRecord,
  });
}

/// Stream provider for real-time visit changes.
final visitRealtimeProvider = StreamProvider<VisitRealtimeEvent>((ref) {
  final client = ref.watch(supabaseProvider);
  final controller = StreamController<VisitRealtimeEvent>();

  final channel = client.channel('console-visits');
  
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'visits',
        callback: (payload) {
          controller.add(VisitRealtimeEvent(
            eventType: payload.eventType.name,
            newRecord: payload.newRecord,
            oldRecord: payload.oldRecord,
          ));
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

/// Stream provider for real-time access decision changes.
/// Console uses this to know when a kiosk visitor gets auto-approved.
final decisionRealtimeProvider = StreamProvider<VisitRealtimeEvent>((ref) {
  final client = ref.watch(supabaseProvider);
  final controller = StreamController<VisitRealtimeEvent>();

  final channel = client.channel('console-decisions');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'access_decisions',
        callback: (payload) {
          controller.add(VisitRealtimeEvent(
            eventType: 'INSERT',
            newRecord: payload.newRecord,
          ));
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
