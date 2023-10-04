import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Entry point of the application. Initializes shared preferences and runs the application.
main() async {
  prefs = await SharedPreferences.getInstance();
  runApp(MaterialApp(title: "Earthqakes App", home: Home()));
}

// Constants for the application
const String ALL = "all"; // Represents all earthquakes
const String BASE_URL =
    "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/SIGNIFICANCE_PERIOD.geojson"; // Base URL for the API
const String DAY = "day"; // Represents a day
const String HOUR = "hour"; // Represents an hour
const String MONTH = "month"; // Represents a month
const int PERIOD_DEFAULT_IDX = 2; // Default index for the period
const String PERIOD_KEY = "Period.key"; // Key for the period
const int SIGNIFICANCE_DEFAULT_IDX = 1; // Default index for the significance

const String SIGNIFICANCE_KEY = "Significance.key"; // Key for the significance
const String SIGNIFICANT = "significant"; // Represents significant earthquakes

const String WEEK = "week"; // Represents a week

const String _1_0 = "1.0"; // Represents earthquakes above 1.0
const String _2_5 = "2.5"; // Represents earthquakes above 2.5

const String _4_5 = "4.5"; // Represents earthquakes above 4.5
// Shared preferences for the application
SharedPreferences prefs;
// Date format for the application
DateFormat _dateFormat = DateFormat("MMMM dd, yyyy h:mm a");
// Number format for latitude
NumberFormat _latNumberFormat = NumberFormat("00.##");
// Number format for longitude
NumberFormat _longNumberFormat = NumberFormat("000.##");

// Number format for parts of a degree
NumberFormat _partNumberFormat = NumberFormat("#0.##");

// Sends a GET request to the provided URL and returns the response as a Map
Future<Map> getJson(String url) async {
  http.Response response = await http.get(url);
  return json.decode(response.body);
}

// Takes a raw distance in kilometers and returns it as a formatted string
String normalizeDistance(num rawKm) {
  double rawKmAbs = rawKm.abs().toDouble();
  return "${_partNumberFormat.format(rawKmAbs)} km";
}

// Takes a raw latitude value and returns it as a formatted string
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

// Takes a raw longitude value and returns it as a formatted string
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

// Represents an entry with a value and a title
class EntryData {
  final String value;
  final String title;

  EntryData(this.value, this.title);
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

// Represents the state of the Home widget, which includes the current URL, sign, period, date, future data, data, and loaded status
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
    _currentSign = _significanceList[
            prefs.getInt(SIGNIFICANCE_KEY) ?? SIGNIFICANCE_DEFAULT_IDX]
        .value;
    _currentPeriod =
        _periodList[prefs.get(PERIOD_KEY) ?? PERIOD_DEFAULT_IDX].value;
    _currentURL = _getURL();
    _init();
  }

  void _onPeriodChanged(final EntryData data) {
    final String newPeriod = data.value;
    if (newPeriod == _currentPeriod) return;
    _currentPeriod = newPeriod;
    prefs.setInt(PERIOD_KEY, _periodList.indexOf(data));
    _onURLChanged(_getURL());
  }

  void _onSignChanged(final EntryData data) {
    final String newSign = data.value;
    if (newSign == _currentSign) return;
    _currentSign = newSign;
    prefs.setInt(SIGNIFICANCE_KEY, _significanceList.indexOf(data));
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
                Text(
                    "Lat: ${normalizeLat(_data[pos]["geometry"]["coordinates"][1])}"),
                Text(
                    "Long: ${normalizeLong(_data[pos]["geometry"]["coordinates"][0])}"),
                Text(
                    "Depth: ${normalizeDistance(_data[pos]["geometry"]["coordinates"][2])}")
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
}
