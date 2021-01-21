import 'dart:async';
import 'dart:convert';
import 'dart:core';
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
      routes: {
        EventHandling.routeName: (context) => EventHandling(),
        ScanQR.routeName: (context) => ScanQR(),
      },
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

  //sets up google maps

  Completer<GoogleMapController> _controller = Completer();
  Completer<GoogleMapController> _myshowController = Completer();

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  void _onMyShowMapCreated(GoogleMapController controller) {
    _myshowController.complete(controller);
  }

  var map_update_counter = 0;
  var my_show_map_update_counter = 0;

  final Set<Marker> localMarkers = Set();
  final Set<Marker> myShowMarkers = Set();

  //gets user location; if automatic doesn't sense, use user city/state, if that doesn't work, use Philadelphia

  Position currentPosition;
  String currentAddress;
  LatLng center = LatLng(39.952583, -75.165222);

  final Geolocator geolocator = Geolocator()..forceAndroidLocationManager;

  void backupLocation(city, state) async {

    final location_lookup = city + "," + state;
    List<Location> coordinates = await locationFromAddress(location_lookup);

    String string_coordinates = coordinates[0].toString();
    List<String> list_coordinates = string_coordinates.split(",");

    String sLatitudeLine = list_coordinates[0];
    String sLongitudeLine = list_coordinates[1];

    List<String> sLatitude = sLatitudeLine.split(": ");
    List<String> sLongitude = sLongitudeLine.split(": ");

    double latitude = double.parse(sLatitude[1]);
    double longitude = double.parse(sLongitude[1]);

    center = LatLng(latitude, longitude);

  }

  _getCurrentLocation() {
    geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((Position position) {
      setState(() {
        currentPosition = position;
        center = LatLng(currentPosition.latitude, currentPosition.longitude);
      });
    }).catchError((e) {
      print(e);

      backupLocation(args.user_city, args.user_state);

      center = LatLng(39.952583, -75.165222);

    });
  }

  //visibility flags

  var fab_visibility = false;
  var ticket_visibility = false;
  var scanner_button_visibility = false;

  //get local show listview
  Future<List<LocalShow>> getLocalShows()

    async {

      //temporary hard-coded inputs
      Map<String, String> input_data = {
        "latitude": center.latitude.toString(),
        "longitude": center.longitude.toString(),
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

      print("local check" + data.body);

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
            i["under_21_flag"],
            i["attending_flag"]);
        localShows.add(localShow);

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
            markerId: MarkerId(i["show_id"]),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(title: i["venue"]),
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

          print("my check" + data.body);

          var jsonData = json.decode(data.body);

          List<MyShow> myShows = [];

          //loop through output
          for (var i in jsonData) {
            MyShow myShow = MyShow(
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
            myShows.add(myShow);

            //get latitude/longitude, create map marker
            final address_lookup = i["venue_address"] + "," +
                i["venue_zip_code"];
            List<Location> coordinates = await locationFromAddress(
                address_lookup);

            String string_coordinates = coordinates[0].toString();
            List<String> list_coordinates = string_coordinates.split(",");

            String sLatitudeLine = list_coordinates[0];
            String sLongitudeLine = list_coordinates[1];

            List<String> sLatitude = sLatitudeLine.split(": ");
            List<String> sLongitude = sLongitudeLine.split(": ");

            double latitude = double.parse(sLatitude[1]);
            double longitude = double.parse(sLongitude[1]);

            myShowMarkers.add(
                Marker(
                  markerId: MarkerId(i["show_id"]),
                  position: LatLng(latitude, longitude),
                  infoWindow: InfoWindow(title: i["month"] + " " + i["day"] + " " + i["venue"]),
                ),
            );
          }

          //update map with markers once or whenever a venue is added
          if (my_show_map_update_counter < 1) {
            setState(() {
              myShowMarkers;
            });
            my_show_map_update_counter = my_show_map_update_counter + 1;
          };

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

        if(data.body.contains('Error') == true){
          print(data.body);
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("Could not finalize RSVP; event may be at max capacity"));
              }
          );

        }

      }

      void cancelButton(user_id_input, show_id_input) async {

        print("cancel test");

        Map<String, String> input_data_cancel = {
          "user_id": user_id_input,
          "show_id": show_id_input,
          "remove_button": "1"
        };

        var url_my_shows = 'https://eqomusic.com/mobile/attendance_management.php';

        var data = await http.post(url_my_shows,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_cancel
        );

      }

      @override
      Widget build(BuildContext context) {

        if(args.user_type == "venue"){
          fab_visibility = true;
        }

        _getCurrentLocation();

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
                        target: center,
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
                                      ),
                                  onPressed: () {
                                    mapRecenter(snapshot.data[int].venue_address, snapshot.data[int].venue_zip_code);
                                  }
                                  ),

                                    trailing:
                                        //keeps attendance buttons for fans only
                                        args.user_type != "fan"?
                                            null
                                            :
                                            snapshot.data[int].attending_flag == 1?
                                                Icon(Icons.check_circle_outline, color: Colors.green)
                                                : GestureDetector(child: Icon(Icons.control_point_rounded, color: Colors.orange),

                                            onTap: (){
                                              my_show_map_update_counter = 0;
                                              String user_id_input = args.user_id;
                                              String show_id_input = snapshot.data[int].show_id;
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
                                    markers: myShowMarkers,
                                    onMapCreated: _onMyShowMapCreated,
                                    myLocationEnabled: true,
                                    initialCameraPosition: CameraPosition(
                                      target: center,
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

                                          title: FlatButton(
                                              child:
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
                                              ),
                                              onPressed: () {
                                                mapRecenter(snapshot.data[int].venue_address, snapshot.data[int].venue_zip_code);
                                              }
                                          ),

                                          trailing:
                                          //adds button for declining rsvp (fans) or editing/canceling event (venues)
                                              GestureDetector(
                                                child: Icon(Icons.event_busy_outlined, color: Colors.red[900]),

                                                onTap: (){

                                                  my_show_map_update_counter = 0;

                                                  if(args.user_type == "fan"){
                                                    cancelButton(args.user_id, snapshot.data[int].show_id);

                                                    setState(() {
                                                      myShowMarkers.removeWhere((Marker marker) => marker.markerId.value == snapshot.data[int].show_id);
                                                    });

                                                  }

                                                  else{
                                                    //passes info from row to navigator
                                                    Navigator.pushNamed(
                                                        context,
                                                        EventHandling.routeName,
                                                        arguments: EventInputs(args.user_id, args.user_type, args.user_city, args.user_city, true, snapshot.data[int].show_id, snapshot.data[int].artist_1, snapshot.data[int].artist_2,
                                                        snapshot.data[int].artist_3, snapshot.data[int].year, snapshot.data[int].month_no, snapshot.data[int].day, snapshot.data[int].time, snapshot.data[int].max_attend, snapshot.data[int].genre));
                                                  }

                                                  //updates ticket/scanner button visibility variable based on time to expand QR code

                                                  var now = new DateTime.now();

                                                  if((args.user_type == "venue") & (now.month == snapshot.data[int].month_no) & (now.day == snapshot.data[int].day) & ((now.hour-13) >= snapshot.data[int].time)){

                                                    switch(scanner_button_visibility){
                                                      case false: {scanner_button_visibility = true;}
                                                      break;
                                                      case true: {scanner_button_visibility = false;}
                                                      break;
                                                    }

                                                  }

                                                  if((args.user_type == "fan") & (now.month == snapshot.data[int].month_no) & (now.day == snapshot.data[int].day) & ((now.hour-13) >= snapshot.data[int].time)){

                                                        switch(ticket_visibility){
                                                          case false: {ticket_visibility = true;}
                                                          break;
                                                          case true: {ticket_visibility = false;}
                                                          break;
                                                        }

                                                  }

                                                },

                                          ),

                                      //QR code area. TO DO: add a scanner here for venues instead
                                      subtitle: args.user_type == "fan" ?

                                      Visibility(
                                          visible: ticket_visibility,
                                          child: QrImage(
                                            data: args.user_id + "#" + snapshot.data[int].show_id + "#" + snapshot.data[int].ticket_color,
                                            version: QrVersions.auto,
                                            size: 200.0,
                                          ),
                                      )

                                      :

                                      Visibility(
                                        visible: scanner_button_visibility,
                                        child: FlatButton(
                                          padding: EdgeInsets.all(15),
                                          onPressed: (){
                                            Navigator.of(context).push(MaterialPageRoute(builder: (context)=> ScanQR()));
                                          },
                                          //TO DO: update colors
                                          child: Text("Scan QR Code",style: TextStyle(color: Colors.indigo[900]),),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            side: BorderSide(color: Colors.indigo[900]),
                                          ),
                                        ),
                                      )

                                      );
                                    },
                                  );
                                },
                              ))),

                        ]))
                  ]

              ), // This trailing comma makes auto-formatting nicer for build methods.

                floatingActionButton: Visibility(
                  visible: fab_visibility,
                  child: FloatingActionButton.extended(
                    onPressed: () {

                      //passes only empty strings to event handling page
                      Navigator.pushNamed(
                        context,
                        EventHandling.routeName,
                        arguments: EventInputs(args.user_id, args.user_type, args.user_city, args.user_state, false, "", "", "", "", "", "", "", "", "", ""));

                    },
                    icon: Icon(Icons.event),
                    label: Text("Create"),
                    backgroundColor: Colors.green,
                    elevation: 20.0,
                    ),
                )
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
  final String under_21_flag; //for whatever reason, having this as int throws error; check later, handling as string for now
  final int attending_flag;

  LocalShow(this.show_id, this.venue, this.genre, this.time,
      this.month, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.under_21_flag, this.attending_flag);

}

class MyShow {
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

  MyShow(this.show_id, this.venue, this.genre, this.time, this.year,
      this.month, this.month_no, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.ticket_color, this.ticket_icon, this.under_21_flag);

}