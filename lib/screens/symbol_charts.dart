import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trading_bot/utilities/candle_data.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import 'package:intl/intl.dart';

class SymbolCharts extends StatefulWidget {
  static String id = 'symbol_charts';

  const SymbolCharts({super.key});

  @override
  State<SymbolCharts> createState() => _SymbolChartsState();
}

class _SymbolChartsState extends State<SymbolCharts> {
  List<String> symbols = [];
  String? selectedSymbol = 'BTCUSDT';
  String? selectedInterval = '1d';
  bool isLoadingSymbols = true;
  bool hasErrorSymbols = false;
  bool isLoadingCandlestick = false;
  bool hasErrorCandlestick = true;
  List<CandleData> candleStickData = [];
  Map<String, dynamic> indicators = {};
  io.Socket? socket;
  Timer? updateTimer;
  String hoveredData = '';

  @override
  void initState() {
    super.initState();
    fetchSymbols();
    initializeSocket();
    // Schedule updates every second
    updateTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => updateData());
  }

  void initializeSocket() {
    socket = io.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
    });

    socket!.on('connect', (_) {
      print('connected');
      subscribeToSymbol();
    });

    socket!.on('candlestick_data', (data) {
      updateChartData(data);
    });

    socket!.on('disconnect', (_) => print('disconnected'));
    socket!.on('error', (error) => print('Error: $error'));
  }

  void subscribeToSymbol() {
    if (selectedSymbol != null) {
      socket!.emit('subscribe', {
        'symbol': selectedSymbol,
        'interval': selectedInterval,
      });
    }
  }

  void updateData() {
    if (selectedSymbol != null) {
      fetchLatestCandleStickData(selectedSymbol);
      fetchIndicators(selectedSymbol!, selectedInterval!);
    }
  }

  Future<void> fetchSymbols() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5000/symbols'));

      if (response.statusCode == 200) {
        setState(() {
          symbols = List<String>.from(json.decode(response.body)['symbols']);
          isLoadingSymbols = false;
          hasErrorSymbols = false;

          if (selectedSymbol != null) {
            fetchCandleStickData(selectedSymbol!);
            fetchIndicators(selectedSymbol!, selectedInterval!);
          }
        });
      } else {
        setState(() {
          isLoadingSymbols = false;
          hasErrorSymbols = true;
        });
        print('Failed to load symbols: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        isLoadingSymbols = false;
        hasErrorSymbols = true;
      });
      print('An error occurred: $error');
    }
  }

  Future<void> fetchCandleStickData(String? symbol) async {
    setState(() {
      isLoadingCandlestick = true;
      hasErrorCandlestick = false;
    });
    try {
      final response = await http.get(Uri.parse(
          'http://127.0.0.1:5000/candlestick_data?symbol=$symbol&interval=$selectedInterval'));

      if (response.statusCode == 200) {
        setState(() {
          candleStickData = (json.decode(response.body) as List)
              .map((data) => CandleData.fromJson(data))
              .toList();
          isLoadingCandlestick = false;
          hasErrorCandlestick = false;
        });
      } else {
        setState(() {
          isLoadingCandlestick = false;
          hasErrorCandlestick = true;
        });
        print('Failed to load candlestick data: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        isLoadingCandlestick = false;
        hasErrorCandlestick = true;
      });
      print('An error has occurred $error');
    }
  }

  Future<void> fetchLatestCandleStickData(String? symbol) async {
    try {
      final response = await http.get(Uri.parse(
          'http://127.0.0.1:5000/candlestick_data?symbol=$symbol&interval=$selectedInterval&limit=1'));

      if (response.statusCode == 200) {
        List<CandleData> latestData = (json.decode(response.body) as List)
            .map((data) => CandleData.fromJson(data))
            .toList();
        if (latestData.isNotEmpty) {
          setState(() {
            candleStickData.addAll(latestData);
            candleStickData = candleStickData
                .skip(candleStickData.length > 500
                    ? candleStickData.length - 500
                    : 0)
                .toList();
          });
        }
      } else {
        print('Failed to load latest candlestick data: ${response.statusCode}');
      }
    } catch (error) {
      print(
          'An error has occurred while fetching the latest candlestick data: $error');
    }
  }

  Future<void> fetchIndicators(String symbol, String interval) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/indicators'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'symbol': symbol, 'interval': interval}),
      );

      if (response.statusCode == 200) {
        setState(() {
          indicators = json.decode(response.body);
        });
      } else {
        print('Failed to load indicators: ${response.statusCode}');
      }
    } catch (error) {
      print('An error has occurred while fetching the indicators: $error');
    }
  }

  void updateChartData(dynamic data) {
    List<CandleData> tempData =
        (data as List).map((data) => CandleData.fromJson(data)).toList();
    if (tempData.isNotEmpty) {
      setState(() {
        candleStickData.addAll(tempData);
        // Keep the list manageable by only keeping the latest 500 data points
        if (candleStickData.length > 500) {
          candleStickData.removeRange(0, candleStickData.length - 500);
        }
      });
    }
  }

  @override
  void dispose() {
    socket?.dispose();
    updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Trading Bot',
            style: TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 147, 119, 196),
      ),
      body: isLoadingSymbols
          ? const Center(child: CircularProgressIndicator())
          : hasErrorSymbols
              ? const Center(child: Text('Failed to load data'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 30.0),
                      Center(
                        child: DropdownButton<String>(
                          value: selectedSymbol,
                          items: symbols
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedSymbol = newValue;
                              if (selectedSymbol != null) {
                                fetchCandleStickData(selectedSymbol!);
                                subscribeToSymbol();
                              }
                            });
                          },
                        ),
                      ),
                      Center(
                        child: DropdownButton<String>(
                          value: selectedInterval,
                          items: <String>[
                            '1m',
                            '5m',
                            '15m',
                            '30m',
                            '1h',
                            '6h',
                            '1d'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedInterval = newValue;
                              if (selectedInterval != null) {
                                fetchCandleStickData(selectedSymbol!);
                                subscribeToSymbol();
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        height: 600,
                        width: 600, // Adjust this height as necessary
                        child: isLoadingCandlestick
                            ? const Center(child: CircularProgressIndicator())
                            : hasErrorCandlestick
                                ? const Center(
                                    child:
                                        Text('Failed to load candlestick data'))
                                : Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: candleStickData.length *
                                            15.0, // Adjust based on data
                                        child: LineChart(
                                          LineChartData(
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots:
                                                    candleStickData.map((data) {
                                                  return FlSpot(
                                                    data.time.toDouble(),
                                                    data.close,
                                                  );
                                                }).toList(),
                                                isCurved: true,
                                                color: Colors.blue,
                                                barWidth: 1,
                                                belowBarData:
                                                    BarAreaData(show: false),
                                              ),
                                            ],
                                            gridData:
                                                const FlGridData(show: true),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    return Text(
                                                      value.toStringAsFixed(0),
                                                      style: const TextStyle(
                                                          fontSize: 8),
                                                    );
                                                  },
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 22,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    final DateTime date = DateTime
                                                        .fromMillisecondsSinceEpoch(
                                                            value.toInt());
                                                    final String formattedDate =
                                                        DateFormat('HH:mm')
                                                            .format(date);
                                                    return Text(
                                                      formattedDate,
                                                      style: const TextStyle(
                                                          fontSize: 8),
                                                    );
                                                  },
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false),
                                              ),
                                            ),
                                            lineTouchData: LineTouchData(
                                              touchTooltipData:
                                                  LineTouchTooltipData(
                                                getTooltipColor:
                                                    (LineBarSpot spot) {
                                                  int index = spot.spotIndex;
                                                  LineChartBarData barData =
                                                      spot.bar;
                                                  List<FlSpot> spots =
                                                      barData.spots;

                                                  if (index > 0) {
                                                    double prevValue =
                                                        spots[index - 1].y;
                                                    if (spot.y > prevValue) {
                                                      return Colors
                                                          .greenAccent; // Value is going up
                                                    } else {
                                                      return Colors
                                                          .redAccent; // Value is going down
                                                    }
                                                  } else {
                                                    return Colors
                                                        .white; // Default color
                                                  }
                                                },
                                              ),
                                              touchCallback:
                                                  (FlTouchEvent event,
                                                      LineTouchResponse?
                                                          touchResponse) {
                                                if (touchResponse != null &&
                                                    touchResponse
                                                            .lineBarSpots !=
                                                        null) {
                                                  final touchedSpot =
                                                      touchResponse
                                                          .lineBarSpots![0];
                                                  final time = touchedSpot.x;
                                                  final value = touchedSpot.y;
                                                  print(
                                                      'Time: $time, Value: $value');
                                                  setState(() {
                                                    hoveredData =
                                                        'Time: $time, Close: $value';
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                      ),
                      if (hoveredData.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(hoveredData),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: indicators['data'] != null
                            ? indicators['data'].length
                            : 0,
                        itemBuilder: (context, index) {
                          final indicator = indicators['data'][index];
                          final id = indicator['id'];
                          final result = indicator['result'];

                          if (result.containsKey('value')) {
                            return ListTile(
                              title: Text('$id: ${result['value']}'),
                            );
                          } else if (result.containsKey('valueMACD')) {
                            return ListTile(
                              title: Text(
                                '$id:\nMACD: ${result['valueMACD']}\nSignal: ${result['valueMACDSignal']}\nHist: ${result['valueMACDHist']}',
                              ),
                            );
                          } else {
                            return ListTile(
                              title: Text('$id: No value found'),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}
