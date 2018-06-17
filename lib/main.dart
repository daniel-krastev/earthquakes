import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String SIGNIFICANT = "significant";
const String ALL = "all";
const String _4_5 = "4.5";
const String _2_5 = "2.5";
const String _1_0 = "1.0";
const String HOUR = "hour";
const String DAY = "day";
const String WEEK = "week";
const String MONTH = "month";

const String PERIOD_KEY = "Period.key";
const String SIGNIFICANCE_KEY = "Significance.key";

const String BASE_URL =
    "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/SIGNIFICANCE_PERIOD.geojson";

const int PERIOD_DEFAULT_IDX = 2;
const int SIGNIFICANCE_DEFAULT_IDX = 1;

SharedPreferences prefs;
DateFormat _dateFormat = DateFormat("MMMM dd, yyyy h:mm a");
NumberFormat _partNumberFormat = NumberFormat("#0.##");
NumberFormat _latNumberFormat = NumberFormat("00.##");
NumberFormat _longNumberFormat = NumberFormat("000.##");

main() async {
  prefs = await SharedPreferences.getInstance();
  runApp(MaterialApp(title: "Earthqakes App", home: Home()));
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class EntryData {
  final String value;
  final String title;

  EntryData(this.value, this.title);
}

class _HomeState extends State<Home> {
  final List<EntryData> _periodList = [
    EntryData(HOUR, "Past Hour"),
    EntryData(DAY, "Past Day"),
    EntryData(WEEK, "Past Week"),
    EntryData(MONTH, "Past Month"),
  ];

  final List<EntryData> _significanceList = [
    EntryData(SIGNIFICANT, "Significant"),
    EntryData(_4_5, "Above 4.5"),
    EntryData(_2_5, "Above 2.5"),
    EntryData(_1_0, "Above 1.0"),
    EntryData(ALL, "All"),
  ];

  String _currentURL, _currentSign, _currentPeriod;
  DateTime _date;
  Future<Map> _futureData;
  List _data;
  bool _isLoaded;

  _HomeState() {
    _currentSign = _significanceList[prefs.getInt(SIGNIFICANCE_KEY) ?? SIGNIFICANCE_DEFAULT_IDX].value;
    _currentPeriod = _periodList[prefs.get(PERIOD_KEY) ?? PERIOD_DEFAULT_IDX].value;
    _currentURL = _getURL();
    _init();
  }

  void _init() {
    _isLoaded = false;
    _futureData = getJson(_currentURL);
    _futureData.then((s) {
      setState(() {
        _data = s['features'];
        _isLoaded = true;
      });
    });
  }

  void _onSignChanged(final EntryData data) {
    final String newSign = data.value;
    if (newSign == _currentSign) return;
    _currentSign = newSign;
    prefs.setInt(SIGNIFICANCE_KEY, _significanceList.indexOf(data));
    _onURLChanged(_getURL());
  }

  void _onPeriodChanged(final EntryData data) {
    final String newPeriod = data.value;
    if (newPeriod == _currentPeriod) return;
    _currentPeriod = newPeriod;
    prefs.setInt(PERIOD_KEY, _periodList.indexOf(data));
    _onURLChanged(_getURL());
  }

  void _onURLChanged(final String newURL) {
    setState(() {
      _currentURL = newURL;
      _isLoaded = false;
      _futureData = getJson(newURL);
      _futureData.then((s) {
        setState(() {
          _data = s['features'];
          _isLoaded = true;
        });
      });
    });
  }

  String _getURL() {
    return BASE_URL
        .replaceAll(RegExp('SIGNIFICANCE'), _currentSign)
        .replaceAll(RegExp('PERIOD'), _currentPeriod);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Column(
            children: <Widget>[
              Text(
                "Earthqakes",
                style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.w300),
              ),
              Text("$_currentSign / $_currentPeriod",
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade300,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w200))
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.redAccent,
          leading: IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _onURLChanged(_currentURL);
            },
          ),
          actions: <Widget>[
            PopupMenuButton<EntryData>(
              icon: Icon(Icons.line_weight),
              onSelected: _onSignChanged,
              itemBuilder: (ctx) {
                return _significanceList.map((a) {
                  return CheckedPopupMenuItem<EntryData>(
                    checked: _currentSign == a.value,
                    child: Text(a.title),
                    value: a,
                  );
                }).toList();
              },
            ),
            PopupMenuButton<EntryData>(
              icon: Icon(Icons.timer),
              onSelected: _onPeriodChanged,
              itemBuilder: (ctx) {
                return _periodList.map((a) {
                  return CheckedPopupMenuItem<EntryData>(
                    checked: _currentPeriod == a.value,
                    child: Text(a.title),
                    value: a,
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: _isLoaded
            ? ListView.builder(
                itemCount: _data.length,
                itemBuilder: _getTile,
              )
            : Center(
                child: Text(
                  "Loading...",
                  style: TextStyle(
                      color: Colors.black26,
                      fontSize: 35.0,
                      fontWeight: FontWeight.w500),
                ),
              ));
  }

  Widget _getTile(BuildContext ctx, int pos) {
    _date = DateTime.fromMillisecondsSinceEpoch(
        _data[pos]["properties"]["time"],
        isUtc: true);
    return Container(
      margin: EdgeInsets.all(4.0),
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: <Widget>[
          ListTile(
            leading: CircleAvatar(
                minRadius: 40.0,
                backgroundColor: Colors.green,
                child: Text("${_data[pos]["properties"]["mag"]}",
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.white))),
            title: Text(
              _dateFormat.format(_date),
              style: TextStyle(
                  color: Colors.orange,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "${_data[pos]["properties"]["place"]}",
              style: TextStyle(fontSize: 14.0, fontStyle: FontStyle.italic),
            ),
            onTap: () {
              _showDialog(ctx, pos);
            },
            onLongPress: () {
              _showLongDialog(ctx, pos);
            },
          ),
          Divider()
        ],
      ),
    );
  }

  void _showLongDialog(ctx, pos) {
    showDialog(
        context: ctx,
        builder: (ctx) {
          return AlertDialog(
            title: Text("Details"),
            content: SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("UTC Time"),
              ],
            )),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("OK"),
              )
            ],
          );
        });
  }

  void _showDialog(BuildContext ctx, int pos) {
    showDialog(
        context: ctx,
        builder: (ctx) {
          return AlertDialog(
            title: Text("Position"),
            content: SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Lat: ${normalizeLat(
                        _data[pos]["geometry"]["coordinates"][1])}"),
                Text("Long: ${normalizeLong(
                        _data[pos]["geometry"]["coordinates"][0])}"),
                Text("Depth: ${normalizeDistance(
                        _data[pos]["geometry"]["coordinates"][2])}")
              ],
            )),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("OK"),
              )
            ],
          );
        });
  }
}

String normalizeLat(num rawLat) {
  double rawLatAbs = rawLat.abs().toDouble();
  if (rawLatAbs <= 90.0) {
    StringBuffer res = StringBuffer();
    double seconds;
    double decimalPart = rawLatAbs - rawLatAbs.truncateToDouble();

    //degree
    res.write(_latNumberFormat.format(rawLatAbs.truncate()));
    res.write("\u00b0 ");
    //minutes
    res.write(_partNumberFormat.format((decimalPart * 60).truncate()));
    res.write("\' ");
    //seconds
    seconds = ((decimalPart * 60) - (decimalPart * 60).truncateToDouble()) * 60;
    res.write(_partNumberFormat.format(seconds));
    res.write("\" ");
    //north or south
    res.write(rawLat.sign == -1.0 ? "S " : (rawLat.sign == 1.0 ? "N " : ""));

    return res.toString();
  }
  return "UNKNOWN";
}

String normalizeLong(num rawLong) {
  double rawLongAbs = rawLong.abs().toDouble();
  if (rawLongAbs <= 180.0) {
    StringBuffer res = StringBuffer();
    double seconds;
    double decimalPart = rawLongAbs - rawLongAbs.truncateToDouble();

    //degree
    res.write(_longNumberFormat.format(rawLongAbs.truncate()));
    res.write("\u00b0 ");
    //minutes
    res.write(_partNumberFormat.format((decimalPart * 60).truncate()));
    res.write("\' ");
    //seconds
    seconds = ((decimalPart * 60) - (decimalPart * 60).truncateToDouble()) * 60;
    res.write(_partNumberFormat.format(seconds));
    res.write("\" ");
    //east or west
    res.write(rawLong.sign == -1.0 ? "W " : (rawLong.sign == 1.0 ? "E " : ""));

    return res.toString();
  }
  return "UNKNOWN";
}

String normalizeDistance(num rawKm) {
  double rawKmAbs = rawKm.abs().toDouble();
  return "${_partNumberFormat.format(rawKmAbs)} km";
}

Future<Map> getJson(String url) async {
  http.Response response = await http.get(url);
  return json.decode(response.body);
}
