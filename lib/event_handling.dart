import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/login.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_typeahead/cupertino_flutter_typeahead.dart';
import 'package:path_provider/path_provider.dart';

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
      routes: {
        MyApp.routeName: (context) => MyApp(),
      },
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

  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

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

  set selectedArtist(String selectedArtist) {}

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

  //function for handling audio medley creation; called in the create event, update event functions

  Future<List<String>> MedleyCreation(artist_1, artist_2, artist_3, show_id)

    async{

      Map<String, String> input_get_urls = {
        "artist_1" : artist_1,
        "artist_2" : artist_2,
        "artist_3": artist_3,
        "show_id" : show_id.toString(),
      };

      //get data from database

      var url_medley = 'https://eqomusic.com/mobile/medley_inputs.php';

      var data = await http.post(url_medley,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: input_get_urls
      );

      print("testing medley inputs" + input_get_urls.toString());
      print("testing medley inputs 2x" + data.body.toString());

      var jsonData = json.decode(data.body);

      print(jsonData);

      if(jsonData.toString().contains('Error') != true){

        //for each url: check for non-empty, if non-empty -> extract 20 second sample -> merge all into one file, put file on firebase

        String song_1_url = "";
        String song_2_url = "";
        String song_3_url = "";

        if(jsonData["song_1_url"] != null){
          song_1_url = jsonData["song_1_url"];
        }

        if(jsonData["song_2_url"] != null){
          song_2_url = jsonData["song_2_url"];
        }

        if(jsonData["song_3_url"] != null){
          song_3_url = jsonData["song_3_url"];
        }

        Directory appDocumentDir = await getExternalStorageDirectory();
        String rawDocumentPath = appDocumentDir.path;

        //NOTE: ASSUMES ALL SONGS LAST AT LEAST 1 MINUTE; WILL NEED TO ADJUST EVENTUALLY

        String song_1_output = "";
        String song_2_output = "";
        String song_3_output = "";
        int input_counter = 0;

        if(song_1_url.length > 0) {
          String song_1_command = "-ss 00:00:40 -t 20 -i " + song_1_url + " -y " + rawDocumentPath + "/song_1_output.wav";
          await _flutterFFmpeg.execute(song_1_command).then((rc) => print("FFmpeg song 1 process exited with rc $rc"));
          song_1_output = rawDocumentPath + "/song_1_output.wav";
          print("checking song output: " + song_1_output);
          input_counter = input_counter + 1;
        }

        if(song_2_url.length > 0) {
          var song_2_arguments = ["-i", song_2_url, "-ss", "40 -to 20 -c -acodec copy", "song_2_output.wav"];
          _flutterFFmpeg.executeWithArguments(song_2_arguments).then((rc) => print("FFmpeg song 2 process exited with rc $rc"));
          song_2_output = rawDocumentPath + show_id + "/song_2_output.mp3";
          input_counter = input_counter + 1;
        }

        if(song_3_url.length > 0) {
          var song_3_arguments = ["-i", song_3_url, "-ss", "40 -to 20 -c copy", "song_3_output.mp3"];
          _flutterFFmpeg.executeWithArguments(song_3_arguments).then((rc) => print("FFmpeg song 3 process exited with rc $rc"));
          song_3_output = rawDocumentPath + show_id.toString() + "/song_3_output.mp3";
          input_counter = input_counter + 1;
        }

        //prepares command information for ffmpeg based on # inputs

        String medley_command = "";

        if(input_counter == 1){
          medley_command = "-i " + song_1_output + " " + song_2_output + " " + song_3_output + " -y " + rawDocumentPath + "/medley_file_output.wav";
        }

        if(input_counter == 2){
          medley_command = "-i " + song_1_output + " " + song_2_output + " " + song_3_output +
              " -filter_complex '[0:0][1:0]concat=n=2:v=0:a=1[out]' -map '[out]' -y " + rawDocumentPath + "/medley_file_output.wav";
        }

        if(input_counter == 3){
          medley_command = "-i " + song_1_output + " " + song_2_output + " " + song_3_output +
              " -filter_complex '[0:0][1:0][2:0]concat=n=3:v=0:a=1[out]' -map '[out]' -y " + rawDocumentPath + "/medley_file_output.wav";
        }

        //concatenates, sends file to firebase, gets download url, sends to SQL database for use in main tab
        print("command for melody: " + medley_command);
        await _flutterFFmpeg.execute(medley_command).then((rc) => print("FFmpeg Medley process exited with rc $rc"));
        String medley_file_output = rawDocumentPath + "/medley_file_output.wav";

        File file = File(medley_file_output);
        print("file string" + file.toString());

        if(file == null){
          print("yes it's actually null");
        }

        String url = "";

        FirebaseStorage _storage = FirebaseStorage.instance;

        if(file != null) {

          StorageReference ref = FirebaseStorage().ref().child("show_" + show_id.toString() + "_medley_file.wav");
          StorageUploadTask uploadTask = ref.putFile(file);

          var dowurl = await (await uploadTask.onComplete).ref.getDownloadURL();

          url = dowurl.toString();

        }

        print("firebase URL" + url);

        Map<String, String> input_medley_download_url = {
          "show_id": show_id.toString(),
          "medley_url": url,
        };

        var url_medley_link = 'https://eqomusic.com/mobile/medley_link_update.php';

        var data = await http.post(url_medley_link,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_medley_download_url
        );

        var jsonData_medley = json.decode(data.body);

        print(jsonData_medley);

      }

    }

  //function for creating event

  Future<List<EventInputs>> CreateEvent(input_month, input_day, input_year, input_max_attend, input_genre, input_artist_1, input_artist_2, input_artist_3, input_time, input_over_21, input_user_id)

  async {

    if(input_over_21 == false){
      under_21_flag = "1";
    }

    if(input_year.length == 2){
      input_year = "20" + input_year;
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

    print("this is a check of the readout" + data.body);

    var jsonData = json.decode(data.body);

    if(jsonData.toString().contains('Error') || jsonData.toString().contains('<b>') == true){

      print("failed!");
      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(title: Text("Something went wrong, please try again"));
          }
      );

    }
    else{

      var show_id = jsonData["show_id"];

      print("will this print?");

      await MedleyCreation(input_artist_1, input_artist_2, input_artist_3, show_id);

      Navigator.pushNamed(
          context,
          MyApp.routeName,
          arguments: LoginOutput(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state, event_args.center));
    }

  }

  //function for updating event

  Future<List<EventInputs>> UpdateEvent(input_year, input_month, input_day, input_max_attend, input_genre, input_artist_1, input_artist_2, input_artist_3, input_time, input_under_21, input_user_id)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_update_event = {
      "edit_event_button" : "yes",
      "show_id" : event_args.show_id,
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

    print(input_update_event.toString());

    //get data from database

    var url_update = 'https://eqomusic.com/mobile/event_management.php';

    var data = await http.post(url_update,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_update_event
    );

    print(data.body.toString());

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

      print("will this print?");

      MedleyCreation(input_artist_1, input_artist_2, input_artist_3, event_args.show_id);

      Navigator.pushNamed(
          context,
          MyApp.routeName,
          arguments: LoginOutput(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state, event_args.center));
    }

  }

  //function for canceling event

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
          arguments: LoginOutput(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state, event_args.center));
    }

  }

  //function for acquiring all artist names (for use in type aheads for choosing artists)

  Future<List<String>> getArtistList()

  async {

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/get_artist_list.php';

    var data = await http.post(url_login,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
    );

    var jsonData = json.decode(data.body);

    List<String> artistNames = [];

    for (var i in jsonData) {
      artistNames.add(i["artist_name"]);
      print(i["artist_name"]);
    }

    return artistNames;

  }

  List<String> artists;

//find and create list of matched strings
  List<String> _getSuggestions(String query) {
    List<String> matches = List();

    matches.addAll(artists);

    matches.retainWhere((s) => s.toLowerCase().contains(query.toLowerCase()));
    return matches;
  }

  //gets user list from db
  void getArtists() async {
    artists = await getArtistList();
  }

  //******************************************************************************************************************
  //Start of the app UI build
  //******************************************************************************************************************

  @override
  Widget build(BuildContext context) {

    getArtists();

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

    final OpenerField = TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
      style: style,
      controller: openerController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Opening Artist",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)))),
      suggestionsCallback: (pattern) {
        return _getSuggestions(pattern);
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text(suggestion),
        );
      },
      transitionBuilder: (context, suggestionsBox, controller) {
        return suggestionsBox;
      },
      onSuggestionSelected: (suggestion) {
        this.openerController.text = suggestion;
      },
      validator: (value) {
        if (value.isEmpty) {
          return 'Please select an artist';
        }
      },
      onSaved: (value) => this.selectedArtist = value,
    );

    final MiddleField = TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
          style: style,
          controller: middleController,
          decoration: InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
              hintText: "Following Artist",
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)))),
      suggestionsCallback: (pattern) {
        return _getSuggestions(pattern);
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text(suggestion),
        );
      },
      transitionBuilder: (context, suggestionsBox, controller) {
        return suggestionsBox;
      },
      onSuggestionSelected: (suggestion) {
        this.openerController.text = suggestion;
      },
      validator: (value) {
        if (value.isEmpty) {
          return 'Please select an artist';
        }
      },
      onSaved: (value) => this.selectedArtist = value,
    );

    final CloserField = TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
          style: style,
          controller: closerController,
          decoration: InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
              hintText: "Closing Artist",
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)))),
      suggestionsCallback: (pattern) {
        return _getSuggestions(pattern);
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text(suggestion),
        );
      },
      transitionBuilder: (context, suggestionsBox, controller) {
        return suggestionsBox;
      },
      onSuggestionSelected: (suggestion) {
        this.openerController.text = suggestion;
      },
      validator: (value) {
        if (value.isEmpty) {
          return 'Please select an artist';
        }
      },
      onSaved: (value) => this.selectedArtist = value,
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
          hintText: "Time (00:00pm)",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final maxAttendanceField = TextField(
      style: style,
      controller: attendanceController,
      keyboardType: TextInputType.number,
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

          UpdateEvent(date_inputs[2], date_inputs[0], date_inputs[1], attendanceController.text, genreController.text, openerController.text, middleController.text, closerController.text, timeController.text, over_21_checkbox.toString(), event_args.user_id);

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

    final BackButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          Navigator.pushNamed(
              context,
              MyApp.routeName,
              arguments: LoginOutput(event_args.user_id, event_args.user_type, event_args.user_city, event_args.user_state, event_args.center));
        },
        child: Text("Go Back",
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
                        //note: this inverts so that, in php, "under 21 flag" is 0 if event is 21+ only
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
                              BackButon,
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
  final LatLng center;

  EventInputs(this.user_id, this.user_type, this.user_city, this.user_state, this.update_flag, this.show_id, this.open_artist, this.follow_artist, this.closer_artist, this.year_input, this.month_input, this.day_input, this.time_input, this.max_attendance, this.genre, this.center);

}

class ArtistName{
  final String artist_name;

  ArtistName(this.artist_name);
}