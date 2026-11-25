import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hundred_days/data/crash_reporting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isExpectedFailure', () {
    test('the network and refused sign-ins are not bugs', () {
      expect(isExpectedFailure(const SocketException('no route')), isTrue);
      expect(isExpectedFailure(TimeoutException('slow')), isTrue);
      expect(isExpectedFailure(http.ClientException('closed')), isTrue);
      expect(isExpectedFailure(const AuthException('Invalid login')), isTrue);
      expect(
        isExpectedFailure(AuthRetryableFetchException(message: 'offline')),
        isTrue,
      );
    });

    test('everything else is reported', () {
      expect(isExpectedFailure(StateError('bad fold')), isFalse);
      expect(isExpectedFailure(const FormatException('bad json')), isFalse);
      expect(
        isExpectedFailure(const PostgrestException(message: 'permission denied')),
        isFalse,
      );
    });
  });
}
