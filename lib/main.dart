import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/login.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const routeName = '/MainScreenRoute';
  // This widget is the root of your application.
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
      home: MyHomePage(args: args),
    );
  }
}

class MyHomePage extends StatefulWidget {

  final String title;
  final LoginOutput args;

  MyHomePage({Key key, this.title, @required this.args}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState(args);

}

class _MyHomePageState extends State<MyHomePage> with AutomaticKeepAliveClientMixin{

  LoginOutput args;

  _MyHomePageState(LoginOutput args) {
    this.args = args;
  }

  //login details - use the below for referencing user id/type elsewhere
  //args.user_id;
  //args.user_type;

  //sets up google maps
  Completer<GoogleMapController> _controller = Completer();

  LatLng _center = LatLng(39.952583, -75.165222);

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  var map_update_counter = 0;

  //initiate map marker sets
  final Set<Marker> localMarkers = Set();
  final Set<Marker> myShowMarkers = Set();

  //get local show listview
  Future<List<LocalShow>> getLocalShows()

    async {

      //temporary hard-coded inputs
      Map<String, String> input_data = {
        "latitude": "39.952583",
        "longitude": "-75.165222",
        "user_id": args.user_id
      };

      //get data from database

      var url = 'https://eqomusic.com/mobile/concert_list_display.php';

      var data = await http.post(url,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: input_data
      );

      var jsonData = json.decode(data.body);

      List<LocalShow> localShows = [];

      //loop through output
      for (var i in jsonData) {
        LocalShow localShow = LocalShow(
            i["show_id"],
            i["venue"],
            i["genre"],
            i["time"],
            i["month"],
            i["day"],
            i["artist_1"],
            i["artist_2"],
            i["artist_3"],
            i["max_attend"],
            i["venue_address"],
            i["venue_zip_code"],
            i["attending_flag"]);
        localShows.add(localShow);

        print(data.body);

        //get latitude/longitude, create map marker
        final address_lookup = i["venue_address"] + "," + i["venue_zip_code"];
        List<Location> coordinates = await locationFromAddress(address_lookup);

        String string_coordinates = coordinates[0].toString();
        List<String> list_coordinates = string_coordinates.split(",");

        String sLatitudeLine = list_coordinates[0];
        String sLongitudeLine = list_coordinates[1];

        List<String> sLatitude = sLatitudeLine.split(": ");
        List<String> sLongitude = sLongitudeLine.split(": ");

        double latitude = double.parse(sLatitude[1]);
        double longitude = double.parse(sLongitude[1]);

        localMarkers.add(
          Marker(
            markerId: MarkerId(i["venue"]),
            position: LatLng(latitude,longitude),
          )
        );
      }

      //update map with markers once
      if(map_update_counter<1) {
        setState(() {
          localMarkers;
        });
        map_update_counter = map_update_counter + 1;
      };

      return localShows;
    }

    //get MyShow listview
    Future<List<MyShow>> getMyShows()

      async {

        Map<String, String> input_data_my_shows = {
          "user_id": args.user_id,
          "user_type" : args.user_type
        };

        //get data from database

        var url_my_shows = 'https://eqomusic.com/mobile/my_show_display.php';

        var data = await http.post(url_my_shows,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_my_shows
        );

        var jsonData = json.decode(data.body);

        List<MyShow> myShows = [];

        //loop through output
        for (var i in jsonData) {
          MyShow myShow = MyShow(
              i["show_id"],
              i["venue"],
              i["genre"],
              i["time"],
              i["month"],
              i["day"],
              i["artist_1"],
              i["artist_2"],
              i["artist_3"],
              i["max_attend"],
              i["venue_address"],
              i["venue_zip_code"],
              i["ticket_color"],
              i["ticket_icon"]);
          myShows.add(myShow);
        }

        print(data.body);

        return myShows;
      }

      //function for recentering google map based on listtile click

      void mapRecenter(venue_address, venue_zip_code) async {

        final address_lookup = venue_address + "," + venue_zip_code;
        List<Location> coordinates = await locationFromAddress(address_lookup);

        String string_coordinates = coordinates[0].toString();
        List<String> list_coordinates = string_coordinates.split(",");

        String sLatitudeLine = list_coordinates[0];
        String sLongitudeLine = list_coordinates[1];

        List<String> sLatitude = sLatitudeLine.split(": ");
        List<String> sLongitude = sLongitudeLine.split(": ");

        double latitude = double.parse(sLatitude[1]);
        double longitude = double.parse(sLongitude[1]);

        GoogleMapController controller = await _controller.future;
        controller.moveCamera(CameraUpdate.newLatLng(LatLng(latitude,longitude)));

      }

      //function for fan pressing attend button
      void attendButton(user_id_input, show_id_input) async {

        print("attend test");

        Map<String, String> input_data_attend = {
          "user_id": user_id_input,
          "show_id": show_id_input,
          "attend_button": "1"
        };

        var url_my_shows = 'https://eqomusic.com/mobile/attendance_management.php';

        var data = await http.post(url_my_shows,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_attend
        );

      }

      @override
      Widget build(BuildContext context) {

        return DefaultTabController(length: 2,
            child:
            Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: [
                    Text("Local Shows"),
                    Text("Your Shows"),
                  ],
                ),
                title: Text('Flutter EQO'),
              ),
              body: TabBarView(
                  children: [(

                      Column(children:[

                      Container(
                      height:250,
                      child:(
                      GoogleMap(
                      markers: localMarkers,
                        onMapCreated: _onMapCreated,
                      myLocationEnabled: true,
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 11.0,
                      ),
                      )
                      )),

                      (
                      Expanded( child: FutureBuilder(
                        future: getLocalShows(),
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
                                  title: FlatButton(
                                  child:
                                      Row(
                                        children: [(Text(snapshot.data[int].venue))]
                                      ),
                                  onPressed: () {
                                    mapRecenter(snapshot.data[int].venue_address, snapshot.data[int].venue_zip_code);
                                  }
                                  ),
                                  trailing: snapshot.data[int].attending_flag == 1?
                                        IconButton(icon: Icon(Icons.check_circle_outline, color: Colors.green))
                                        : IconButton(icon: Icon(Icons.control_point_rounded, color: Colors.orange),
                                        onPressed: (){
                                          print("will this work");
                                          String user_id_input = args.user_id;
                                          String show_id_input = snapshot.data[int].show_id;
                                          Icon(Icons.check_circle_outline, color: Colors.green);
                                          attendButton(user_id_input, show_id_input);
                                              setState(() {
                                                Icon(Icons.check_circle_outline, color: Colors.green);
                                              });
                                            }
                                  )
                                );
                              },
                            );
                              }
                              )
                      )),

                      ])),

                    (

                        Column(children:[

                          Container(
                              height:250,
                              child:(
                                  GoogleMap(
                                    onMapCreated: _onMapCreated,
                                    myLocationEnabled: true,
                                    initialCameraPosition: CameraPosition(
                                      target: _center,
                                      zoom: 11.0,
                                    ),
                                  )
                              )),

                          (
                              Expanded( child: FutureBuilder(
                                future: getMyShows(),
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
                                          title: Text(snapshot.data[int].genre),
                                        );

                                      }

                                  );
                                },
                              ))),

                        ]))
                  ]


              ), // This trailing comma makes auto-formatting nicer for build methods.
            ));
      }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
    }

class LocalShow {
  final String show_id;
  final String venue;
  final String genre;
  final String time;
  final String month;
  final String day;
  final String artist_1;
  final String artist_2;
  final String artist_3;
  final String max_attend;
  final String venue_address;
  final String venue_zip_code;
  final int attending_flag;

  LocalShow(this.show_id, this.venue, this.genre, this.time,
      this.month, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.attending_flag);

}

class MyShow {
  final String show_id;
  final String venue;
  final String genre;
  final String time;
  final String month;
  final String day;
  final String artist_1;
  final String artist_2;
  final String artist_3;
  final String max_attend;
  final String venue_address;
  final String venue_zip_code;
  final String ticket_color;
  final String ticket_icon;

  MyShow(this.show_id, this.venue, this.genre, this.time,
      this.month, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.ticket_color, this.ticket_icon);

}