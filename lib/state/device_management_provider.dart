import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/device_service.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());
