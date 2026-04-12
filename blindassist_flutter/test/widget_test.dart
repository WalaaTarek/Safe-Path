import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:blindassist_flutter/main.dart'; 
 void main() { testWidgets('Basic BlindAssistApp test', (WidgetTester tester) async { 
  await tester.pumpWidget(BlindAssistApp());
  expect(find.text('No objects detected'), findsOneWidget); });
  }