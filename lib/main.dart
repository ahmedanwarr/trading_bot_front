import 'package:flutter/material.dart';
import 'package:trading_bot/screens/symbol_charts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading Bot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: SymbolCharts.id,
      routes: {
        SymbolCharts.id: (context) => SymbolCharts(),
      },
    );
  }
}
