// Represents a time range for scheduling restrictions.
import 'package:flutter/material.dart';

class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeRange({required this.start, required this.end});
}