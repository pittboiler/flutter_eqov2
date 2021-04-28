import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_eqo_v2/event_handling.dart';
import 'package:flutter_eqo_v2/login.dart';
import 'package:flutter_eqo_v2/scan_QR.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() {
  runApp(ArtistMain());
}

class ArtistMain extends StatelessWidget {
  static const routeName = '/ArtistMainRoute';

  @override
  Widget build(BuildContext context) {

    //bring in login details
    final LoginOutput args = ModalRoute.of(context).settings.arguments;

    return MaterialApp(
      title: 'EQO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ArtistMainPage(args: args),
    );
  }
}

class ArtistMainPage extends StatefulWidget {

  final String title;
  final LoginOutput args;

  ArtistMainPage({Key key, this.title, @required this.args}) : super(key: key);

  @override
  _MyArtistState createState() => _MyArtistState(args);
}

class _MyArtistState extends State<ArtistMainPage> {

  LoginOutput args;

  _MyArtistState(LoginOutput args) {
    this.args = args;
  }

  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  String artist_name = "";
  String artist_genre = "";
  String artist_location = "";
  String song_1_name = "";
  String song_2_name = "";
  String song_3_name = "";
  int upcoming_shows = 0;
  double total_att      = 0.0;
  double past_shows     = 0.0;
  double avg_attendance = 0.0;

  TextEditingController SongOneController = TextEditingController();
  TextEditingController SongTwoController = TextEditingController();
  TextEditingController SongThreeController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    SongOneController.dispose();
    SongTwoController.dispose();
    SongThreeController.dispose();
    super.dispose();
  }

  //function to pull artist information (name/location/genre, stats)
  //TO DO: add in song names as well eventually

  int artist_pull_counter = 0;

  Future<void> ArtistInfo()

  async {

    //temporary hard-coded inputs
    Map<String, String> artist_id_lookup = {
      "user_id" : args.user_id,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/artist_lookup.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: artist_id_lookup
    );

    var jsonData = json.decode(data.body);

    print(jsonData);

    if(data.body.contains('Error') == true){
      setState(() {
        artist_name = "N/A";
        artist_genre = "N/A";
        artist_location = "N/A";
        song_1_name = "";
        song_2_name = "";
        song_3_name = "";
      });
    }
    else{
      setState(() {
        artist_name = jsonData["artist_name"];
        artist_genre = jsonData["artist_genre"];
        song_1_name = jsonData["song_1_name"];
        song_2_name = jsonData["song_2_name"];
        song_3_name = jsonData["song_3_name"];
        artist_location = args.user_city + ", " + args.user_state;

        var upcoming_shows_string = jsonData["future_shows"].toString().split(":");
        upcoming_shows = int.parse(upcoming_shows_string[1].substring(0,upcoming_shows_string[1].length - 1));

        var total_att_string = jsonData["total_att"].toString().split(":");
        total_att = double.parse(total_att_string[1].substring(0,total_att_string[1].length - 1));

        var past_shows_string = jsonData["past_shows"].toString().split(":");
        past_shows = double.parse(past_shows_string[1].substring(0,past_shows_string[1].length - 1));

        if(past_shows > 0.0){
          avg_attendance = total_att / past_shows;
        }

        if(song_1_name.length > 0){
          SongOneController = TextEditingController(text: song_1_name);
        }

        if(song_2_name.length > 0){
          SongTwoController = TextEditingController(text: song_2_name);
        }

        if(song_3_name.length > 0){
          SongThreeController = TextEditingController(text: song_3_name);
        }

      });
    }

    artist_pull_counter = 1;

  }

  //get MyShow listview
  Future<List<ArtistShow>> getArtistShows()

  async {

    Map<String, String> input_data_artist_shows = {
      "user_id": args.user_id,
    };

    //get data from database

    var url_my_shows = 'https://eqomusic.com/mobile/artist_show_display.php';

    var data = await http.post(url_my_shows,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_data_artist_shows
    );

    print("my check" + data.body);

    var jsonData = json.decode(data.body);

    List<ArtistShow> artistShows = [];

    //loop through output
    for (var i in jsonData) {
      ArtistShow artistShow = ArtistShow(
          i["show_id"],
          i["venue"],
          i["genre"],
          i["time"],
          i["year"],
          i["month"],
          i["month_no"],
          i["day"],
          i["artist_1"],
          i["artist_2"],
          i["artist_3"],
          i["max_attend"],
          i["venue_address"],
          i["venue_zip_code"],
          i["ticket_color"],
          i["ticket_icon"],
          i["under_21_flag"]);
      artistShows.add(artistShow);

    }

    return artistShows;

  }

  //song upload function

  Future SongPick(String position) async {

    FilePickerResult result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3']);

    if(result != null) {

      //upload song to firebase
      File file = File(result.files.single.path);

      String url = "";

      StorageReference storageReference;
      final StorageUploadTask uploadTask = storageReference.putFile(file);
      final StorageTaskSnapshot downloadUrl = (await uploadTask.onComplete);
      url = (await downloadUrl.ref.getDownloadURL());

      //if url is received, update database info with link, song name

      if(url != "") {

        Map<String, String> input_song_download_url = {
          "user_id": args.user_id,
          "song_url": url,
          "song_name": SongOneController.text,
          "song_position": position,
        };

        //get data from database

        var url_song_upload = 'https://eqomusic.com/mobile/artist_song_upload.php';

        var upload_song_url = await http.post(url_song_upload,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_song_download_url
        );

        var jsonData = json.decode(upload_song_url.body);

        if (jsonData == "Record updated successfully") {
          return showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(title: Text("Song uploaded successfully"));
              }
          );
        }
        else {
          return showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                    title: Text("Song was not uploaded, try again"));
              }
          );
        }
      }
      else {
        return showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  title: Text("Song was not uploaded, try again"));
            }
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    if(artist_pull_counter < 1){
      ArtistInfo();
    }

    final SongOneNameField = TextField(
      style: style,
      controller: SongOneController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Song Name",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(32.0), bottomLeft: Radius.circular(32.0)))),
    );

    final SongTwoNameField = TextField(
      style: style,
      controller: SongTwoController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "SongName",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(32.0), bottomLeft: Radius.circular(32.0)))),
    );

    final SongThreeNameField = TextField(
      style: style,
      controller: SongThreeController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "SongName",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(32.0), bottomLeft: Radius.circular(32.0)))),
    );

    final SongOneButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.only(topRight: Radius.circular(32.0), bottomRight: Radius.circular(32.0)),
      color: song_1_name.length>0 ? Colors.blue : Colors.green,
      child: MaterialButton(
        minWidth: 5,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          SongPick("1");
        },
        child: Icon(Icons.cloud_upload, color: Colors.white),
      ),
    );

    final SongTwoButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.only(topRight: Radius.circular(32.0), bottomRight: Radius.circular(32.0)),
      color: song_2_name.length>0 ? Colors.blue : Colors.green,
      child: MaterialButton(
        minWidth: 5,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          SongPick("2");
        },
        child: Icon(Icons.cloud_upload, color: Colors.white),
      ),
    );

    final SongThreeButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.only(topRight: Radius.circular(32.0), bottomRight: Radius.circular(32.0)),
      color: song_3_name.length>0 ? Colors.blue : Colors.green,
      child: MaterialButton(
        minWidth: 5,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          SongPick("3");
        },
        child: Icon(Icons.cloud_upload, color: Colors.white),
      ),
    );

    return Scaffold(
        appBar: AppBar(
          title: Text('Flutter EQO'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              height: 1000,
              child:
                  Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[

                    Row(

                    children: [

                      Expanded(
                        flex: 2,
                        child: GridView.count(
                            crossAxisCount: 1,
                            childAspectRatio: 2.9,
                            padding: const EdgeInsets.all(1.0),
                            mainAxisSpacing: 0,
                            crossAxisSpacing: 10.0,
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            children: [
                              Align(alignment: Alignment.center, child: Text(artist_name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                              Align(alignment: Alignment.center, child: Text(artist_genre, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                              Align(alignment: Alignment.center, child: Text(artist_location, textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic))),
                            ]
                        )
                    ),

                    Expanded(
                        flex: 2,
                        child: GridView.count(
                            crossAxisCount: 1,
                            childAspectRatio: 4.3,
                            padding: const EdgeInsets.all(1.0),
                            mainAxisSpacing: 0,
                            crossAxisSpacing: 10.0,
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            children: [
                              Align(alignment: Alignment.center, child: Text("Upcoming Shows", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 17))),
                              Align(alignment: Alignment.center, child: Text(upcoming_shows.toString(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                              Align(alignment: Alignment.center, child: Text("Avg. Attendance", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 17))),
                              Align(alignment: Alignment.center, child: Text(avg_attendance.toString(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                            ]
                        )
                    ),

                    ]),

                    SizedBox(height: 25.0),

                    Row(
                      children: [
                        Expanded(
                            flex: 1,
                            child: Text("")
                        ),
                        Expanded(
                          flex: 6,
                          child:SongOneNameField
                        ),
                        Expanded(
                            flex: 2,
                            child:SongOneButon
                        ),
                        Expanded(
                            flex: 1,
                            child: Text("")
                        ),
                      ],
                    ),
                    SizedBox(height: 25.0),
                    Row(
                      children: [
                        Expanded(
                            flex: 1,
                            child: Text("")
                        ),
                        Expanded(
                            flex: 6,
                            child:SongTwoNameField
                        ),
                        Expanded(
                            flex: 2,
                            child:SongTwoButon
                        ),
                        Expanded(
                            flex: 1,
                            child: Text("")
                        ),
                      ],
                    ),
                    SizedBox(height: 25.0),
                    Row(
                      children: [
                        Expanded(
                            flex: 1,
                            child: Text("")
                        ),
                        Expanded(
                            flex: 6,
                            child:SongThreeNameField
                        ),
                        Expanded(
                            flex: 2,
                            child:SongThreeButon
                        ),
                        Expanded(
                            flex: 1,
                            child: Text("")
                        ),
                      ],
                    ),
                    SizedBox(height: 25.0),
                    //need upcoming show list here
                      Expanded( child: FutureBuilder(
                        future: getArtistShows(),
                        builder: (BuildContext context, AsyncSnapshot snapshot){

                          if(snapshot.data == null) {
                            return Container(
                                child: Center(
                                    child: new CircularProgressIndicator()
                                )
                            );
                          }

                          return ListView.builder(
                            itemCount: snapshot.data.length,
                            itemBuilder: (context, int){
                              return ListTile(
                                  title: Expanded(
                                    flex: 8,
                                      child: Row(
                                      children: [
                                        Expanded(
                                            flex: 2,
                                            child: GridView.count(
                                                crossAxisCount: 1,
                                                childAspectRatio: 2.9,
                                                padding: const EdgeInsets.all(1.0),
                                                mainAxisSpacing: 0,
                                                crossAxisSpacing: 10.0,
                                                physics: NeverScrollableScrollPhysics(),
                                                shrinkWrap: true,
                                                children: [
                                                  Align(alignment: Alignment.center, child: Text(snapshot.data[int].month, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                                  Align(alignment: Alignment.center, child: Text(snapshot.data[int].day, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                                  Align(alignment: Alignment.center, child: Text(snapshot.data[int].time.substring(0,5), textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic))),
                                                ]
                                            )
                                        ),
                                        Expanded(
                                            flex: 8,
                                            child: Column(
                                                children: [
                                                  GridView.count(
                                                      crossAxisCount: 3,
                                                      childAspectRatio: 2.5,
                                                      padding: const EdgeInsets.all(1.0),
                                                      mainAxisSpacing: 0,
                                                      crossAxisSpacing: 10.0,
                                                      physics: NeverScrollableScrollPhysics(),
                                                      shrinkWrap: true,
                                                      children: [
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].venue, textAlign: TextAlign.center)),
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].genre, textAlign: TextAlign.center)),

                                                        snapshot.data[int].under_21_flag == "0"?
                                                        Align(alignment: Alignment.center, child: Text("18+", textAlign: TextAlign.center))
                                                            :
                                                        Align(alignment: Alignment.center, child: Text("21+", textAlign: TextAlign.center)),
                                                      ]
                                                  ),
                                                  GridView.count(
                                                      crossAxisCount: 3,
                                                      childAspectRatio: 2.5,
                                                      padding: const EdgeInsets.all(1.0),
                                                      mainAxisSpacing: 0,
                                                      crossAxisSpacing: 10.0,
                                                      physics: NeverScrollableScrollPhysics(),
                                                      shrinkWrap: true,
                                                      children: [
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].artist_1, textAlign: TextAlign.center)),
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].artist_2, textAlign: TextAlign.center)),
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].artist_3, textAlign: TextAlign.center)),
                                                      ]
                                                  )
                                                ]))
                                      ]
                                  )
                              ));
                            },
                          );
                        },
                      )),
                    ]
              )),
            ),
          ),
        )
    );
  }
}

class ArtistShow {
  final String show_id;
  final String venue;
  final String genre;
  final String time;
  final String year;
  final String month;
  final String month_no;
  final String day;
  final String artist_1;
  final String artist_2;
  final String artist_3;
  final String max_attend;
  final String venue_address;
  final String venue_zip_code;
  final String ticket_color;
  final String ticket_icon;
  final String under_21_flag; //for whatever reason, having this as int throws error; check later, handling as string for now

  ArtistShow(this.show_id, this.venue, this.genre, this.time, this.year,
      this.month, this.month_no, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.ticket_color, this.ticket_icon, this.under_21_flag);

}