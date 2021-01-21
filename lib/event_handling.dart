import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';

void main() => runApp(EventHandling());

class EventHandling extends StatelessWidget {

  static const routeName = '/EventHandlingRoute';

  @override
  Widget build(BuildContext context) {

    //pass vars from main page depending on create/update button; create brings empty values for show-specific fields, update brings in relevant values
    final EventInputs event_args = ModalRoute.of(context).settings.arguments;

    return MaterialApp(
      title: 'EQO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: EventHandlingPage(event_args: event_args),
    );
  }
}

class EventHandlingPage extends StatefulWidget {
  EventHandlingPage({Key key, this.title, @required this.event_args}) : super(key: key);

  final String title;
  final EventInputs event_args;

  @override
  _MyEventFormState createState() => _MyEventFormState(event_args);
}

class _MyEventFormState extends State<EventHandlingPage> {

  EventInputs event_args;

  _MyEventFormState(EventInputs event_args) {
    this.event_args = event_args;
  }

  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  TextEditingController openerController = TextEditingController();
  TextEditingController middleController = TextEditingController();
  TextEditingController closerController = TextEditingController();
  TextEditingController dateController = MaskedTextController(mask: "00/00/0000");
  TextEditingController timeController = MaskedTextController(mask: "00:00");
  TextEditingController attendanceController = TextEditingController();
  TextEditingController genreController = TextEditingController();

  bool over_21_checkbox = false;
  String under_21_flag = "0";

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    openerController.dispose();
    middleController.dispose();
    closerController.dispose();
    dateController.dispose();
    timeController.dispose();
    attendanceController.dispose();
    genreController.dispose();
    super.dispose();
  }

  //FUNCTIONS HAVE NOT YET BEEN TESTED

  //function for creating event

  Future<List<EventInputs>> CreateEvent(input_year, input_month, input_day, input_max_attend, input_genre, input_artist_1, input_artist_2, input_artist_3, input_time, input_over_21, input_user_id)

  async {

    if(input_over_21 == false){
      under_21_flag = "1";
    }

    Map<String, String> input_create_event = {
      "create_event" : "yes",
      "year" : input_year,
      "month": input_month,
      "day" : input_day,
      "max_attend" : input_max_attend,
      "genre" : input_genre,
      "artist_1" : input_artist_1,
      "artist_2" : input_artist_2,
      "artist_3" : input_artist_3,
      "time" : input_time,
      "under_21" : under_21_flag,
      "user_id" : input_user_id,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/event_management.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_create_event
    );

    var jsonData = json.decode(data.body);

    if(jsonData.contains('Error') == true){

      print("failed!");
      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(title: Text("Something went wrong, please try again"));
          }
      );

    }
    else{
      Navigator.pushNamed(
          context,
          MyApp.routeName,
          arguments: UserData(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state));
    }

  }

  //function for updating event

  Future<List<EventInputs>> UpdateEvent(input_year, input_month, input_day, input_max_attend, input_genre, input_artist_1, input_artist_2, input_artist_3, input_time, input_under_21, input_user_id)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_update_event = {
      "edit_event_button" : "yes",
      "year" : input_year,
      "month": input_month,
      "day" : input_day,
      "max_attend" : input_max_attend,
      "genre" : input_genre,
      "artist_1" : input_artist_1,
      "artist_2" : input_artist_2,
      "artist_3" : input_artist_3,
      "time" : input_time,
      "under_21" : input_under_21,
      "user_id" : input_user_id,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/event_management.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_update_event
    );

    var jsonData = json.decode(data.body);

    if(jsonData.contains('Error') == true){
      //need to fix this
      print("failed!");
      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(title: Text("Something went wrong, please try again"));
          }
      );

    }
    else{
      Navigator.pushNamed(
          context,
          MyApp.routeName,
          arguments: UserData(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state));
    }

  }

  //function for updating event

  Future<List<EventInputs>> CancelEvent(input_show_id)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_update_event = {
      "delete_event_button" : "yes",
      "show_id" : input_show_id,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/event_management.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_update_event
    );

    var jsonData = json.decode(data.body);

    if(jsonData.contains('Error') == true){
      //need to fix this
      print("failed!");
      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(title: Text("Something went wrong, please try again"));
          }
      );

    }
    else{
      Navigator.pushNamed(
          context,
          MyApp.routeName,
          arguments: UserData(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state));
    }

  }

  @override
  Widget build(BuildContext context) {



    //updates field values if show is being updated
    if(event_args.update_flag == true) {
      openerController = TextEditingController(text: event_args.open_artist);
      middleController = TextEditingController(text: event_args.follow_artist);
      closerController = TextEditingController(text: event_args.closer_artist);

      if(event_args.month_input.length == 1) {
        dateController = MaskedTextController(mask: "00/00/0000", text: "0" + event_args.month_input + event_args.day_input + event_args.year_input.substring((event_args.year_input.length-4).clamp(0, event_args.year_input.length)));
      }
      else {
        dateController = MaskedTextController(mask: "00/00/0000", text: event_args.month_input + event_args.day_input + event_args.year_input.substring((event_args.year_input.length-4).clamp(0, event_args.year_input.length)));
      }

      timeController = MaskedTextController(mask: "00:00", text: event_args.time_input.substring(0,5));
      attendanceController = TextEditingController(text: event_args.max_attendance);
      genreController = TextEditingController(text: event_args.genre);
    }

    final OpenerField = TextField(
      style: style,
      controller: openerController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Opening Artist",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final MiddleField = TextField(
      style: style,
      controller: middleController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Following Artist",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final CloserField = TextField(
      style: style,
      controller: closerController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Closing Artist",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final dateField = TextField(
      style: style,
      controller: dateController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Date (mm/dd/yy)",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final timeField = TextField(
      style: style,
      controller: timeController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Time (pm only)",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final maxAttendanceField = TextField(
      style: style,
      controller: attendanceController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Max EQO Attendance",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final genreField = TextField(
      style: style,
      controller: genreController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Genre",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final CreateButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {

          List<String> date_inputs = dateController.text.split("/");

          CreateEvent(date_inputs[0], date_inputs[1], date_inputs[2], attendanceController.text, genreController.text, openerController.text, middleController.text, closerController.text, timeController.text, over_21_checkbox, event_args.user_id);

        },
        child: Text("Create Event",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    final UpdateButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {

          List<String> date_inputs = dateController.text.split("/");

          UpdateEvent(date_inputs[0], date_inputs[1], date_inputs[2], attendanceController.text, genreController.text, openerController.text, middleController.text, closerController.text, timeController.text, over_21_checkbox, event_args.user_id);

        },
        child: Text("Update Event",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    final CancelButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          CancelEvent(event_args.show_id);
        },
        child: Text("Cancel Event",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    return Scaffold(
        appBar: AppBar(
          title: Text('Flutter EQO'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(height: 45.0),
                    OpenerField,
                    SizedBox(height: 25.0),
                    MiddleField,
                    SizedBox(height: 25.0),
                    CloserField,
                    SizedBox(height: 25.0),
                    dateField,
                    SizedBox(height: 25.0),
                    timeField,
                    SizedBox(height: 25.0),
                    maxAttendanceField,
                    SizedBox(height: 25.0),
                    genreField,
                    SizedBox(height: 25.0),
                    Row(
                    children: [
                      Checkbox(
                        value: over_21_checkbox,
                          onChanged: (value) {
                            setState(() {
                              over_21_checkbox = !over_21_checkbox;
                            });
                          },
                        ),
                      Text('Is this 21 only?'),
                      ],
                    ),
                    Visibility(
                        visible: !event_args.update_flag,
                        child:
                        Column(
                            children:[
                              SizedBox(
                                height: 35.0,
                              ),
                              CreateButon,
                            ]
                        )
                    ),
                    Visibility(
                        visible: event_args.update_flag,
                        child:
                        Column(
                            children: [
                              SizedBox(
                                height: 15.0,
                              ),
                              UpdateButon,
                              SizedBox(
                                height: 15.0,
                              ),
                              CancelButon,
                              SizedBox(
                                height: 15.0,
                              ),
                            ]
                        )
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}

class EventInputs {
  final String user_id;
  final String user_type;
  final String user_city;
  final String user_state;
  final bool update_flag;
  final String show_id;
  final String open_artist;
  final String follow_artist;
  final String closer_artist;
  final String year_input;
  final String month_input;
  final String day_input;
  final String time_input;
  final String max_attendance;
  final String genre;

  EventInputs(this.user_id, this.user_type, this.user_city, this.user_state, this.update_flag, this.show_id, this.open_artist, this.follow_artist, this.closer_artist, this.year_input, this.month_input, this.day_input, this.time_input, this.max_attendance, this.genre);

}