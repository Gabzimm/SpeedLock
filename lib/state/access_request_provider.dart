import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/access_request_service.dart';

final accessRequestServiceProvider = Provider<AccessRequestService>((ref) => AccessRequestService());
