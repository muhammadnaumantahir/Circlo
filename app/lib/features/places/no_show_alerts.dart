import 'place_models.dart';

/// A derived No Show feed item. The alert is intentionally evaluated on active clients;
/// this helper does not schedule background work or send phone push notifications.
class NoShowAlert {
  const NoShowAlert({required this.id, required this.text, required this.at});

  final String id;
  final String text;
  final DateTime at;
}

/// Evaluates one expected-arrival plan against confirmed place events and the latest
/// location timestamp. Pure logic keeps alert boundaries testable and consistent.
NoShowAlert? evaluateNoShowAlert({
  required String circleId,
  required String viewerUid,
  required ArrivalPlan plan,
  required String? memberName,
  required bool memberSharesLocation,
  required bool memberPaused,
  required Place? place,
  required DateTime? latestLocationAt,
  required Iterable<PlaceEvent> recentPlaceEvents,
  required DateTime now,
  required DateTime cutoff,
}) {
  // The owner of the plan manages their own journey; only their other circle members get alerts.
  if (plan.memberUid == viewerUid ||
      memberName == null ||
      memberName.trim().isEmpty ||
      place == null ||
      !memberSharesLocation ||
      memberPaused) {
    return null;
  }

  if (plan.isPending) {
    if (plan.expectedAt.isAfter(now) || plan.expectedAt.isBefore(cutoff)) return null;

    PlaceEvent? recordedArrival;
    for (final event in recentPlaceEvents) {
      if (event.memberUid == plan.memberUid &&
          event.placeId == plan.placeId &&
          event.type == 'arrive' &&
          event.occurredAt != null &&
          plan.createdAt != null &&
          !event.occurredAt!.isBefore(plan.createdAt!)) {
        recordedArrival = event;
        break;
      }
    }

    if (recordedArrival?.occurredAt != null) {
      final arrivedAt = recordedArrival!.occurredAt!;
      if (!arrivedAt.isAfter(plan.expectedAt)) {
        // An on-time confirmed arrival resolves the pending plan.
        return null;
      }
      // Preserve a late-arrival item if the place event saved but the plan completion did not.
      return NoShowAlert(
        id: '${circleId}/no-show-late-event/${plan.id}',
        text: 'Circlo recorded ${memberName} arriving at ${place.name} after the expected time.',
        at: arrivedAt,
      );
    }

    final locationAge = latestLocationAt == null ? null : now.difference(latestLocationAt);
    // Treat clocks more than 2 minutes ahead as untrusted, instead of implying a fresh location.
    final stale = locationAge == null ||
        locationAge > const Duration(minutes: 15) ||
        locationAge < const Duration(minutes: -2);
    return NoShowAlert(
      id: '${circleId}/no-show/${plan.id}',
      text: stale
          ? '${memberName} has no arrival recorded at ${place.name} by the expected time. Their location may be unavailable.'
          : '${memberName} has no arrival recorded at ${place.name} by the expected time.',
      at: plan.expectedAt,
    );
  }

  if (plan.arrivedLate &&
      plan.arrivedAt != null &&
      !plan.arrivedAt!.isBefore(cutoff)) {
    return NoShowAlert(
      id: '${circleId}/no-show-late/${plan.id}',
      text: '${memberName} arrived at ${place.name} after the expected time.',
      at: plan.arrivedAt!,
    );
  }

  return null;
}
