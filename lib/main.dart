import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_eqo_v2/event_handling.dart';
import 'package:flutter_eqo_v2/login.dart';
import 'package:flutter_eqo_v2/payment_screen.dart';
import 'package:flutter_eqo_v2/scan_QR.dart';
import 'package:flutter_eqo_v2/venue_settings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:stripe_payment/stripe_payment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
        VenueSettings.routeName: (context) => VenueSettings(),
        Payment.routeName: (context) => Payment(),
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

  @override
  void initState() {
    StripePayment.setOptions(StripeOptions(
        publishableKey: "pk_test_51Ip1nEBwbtoLyuGPq2r3m3roNooFxmbUCK6YKT3GetLq3w28ATrVlfMeOH8GIxtfz4JACK6o909Emyi20hqNWSYL007wAKvqRG"));
    super.initState();
  }

  //sets up audio player

  AudioCache audioCache = new AudioCache();
  AudioPlayer audioPlayer = new AudioPlayer();
  String SoundFilePath;
  int play_pause_flag = 0;

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
  var location_update_counter = 0;

  final Set<Marker> localMarkers = Set();
  final Set<Marker> myShowMarkers = Set();

  //gets user location; if automatic doesn't sense, use user city/state, if that doesn't work, use Philadelphia. Note, this could likely be improved

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

  _getCurrentLocation() async {
    if(location_update_counter < 2) {
      geolocator
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
          .then((Position position) {
          currentPosition = position;
          center = LatLng(currentPosition.latitude, currentPosition.longitude);
          print(center);
      }).catchError((e) {
        print(e);
        try {
          backupLocation(args.user_city, args.user_state);
        } on Exception catch (e) {
          print(e);
          center = LatLng(39.952583, -75.165222);
        }
      });
      location_update_counter = location_update_counter + 1;
      GoogleMapController controller = await _controller.future;
      controller.moveCamera(CameraUpdate.newLatLng(center));
    }
  }

  //visibility flags to add a show, show a ticket, and show the scanner button

  var fab_visibility = false;
  var ticket_visibility = false;
  var scanner_button_visibility = false;

  //function to pull venue information (name/location, stats. Note, top 5 shows are used for trailing metrics; can be updated in php file, potentially make it variable in-app later)

  String venue_name = "";
  String venue_location = "";
  double upcoming_shows = 0.0;
  double upcoming_rsvps = 0.0;
  double total_p_rsvps  = 0.0;
  double total_att      = 0.0;
  double avg_f_rsvps    = 0.0;
  double avg_past_rsvps = 0.0;
  double avg_attendance = 0.0;
  double past_shows     = 0.0;

  int venue_pull_counter = 0;

  //function for acquiring dashboard data
  Future<void> VenueInfo()

  async {

    Map<String, String> venue_id_lookup = {
      "user_id" : args.user_id,
    };

    print("subscription check" + args.subscription_flag + "," + args.final_month_flag);

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/venue_lookup.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: venue_id_lookup
    );

    var jsonData = json.decode(data.body);

    print(jsonData);

    if(data.body.contains('Error') == true){
      setState(() {
        venue_name = "N/A";
        venue_location = "N/A";
      });
    }
    else{
      setState(() {

        //FYI: this looks bad because of the difficulty handling doubles and strings.

        venue_name = jsonData["artist_name"];
        venue_location = args.user_city + ", " + args.user_state;

        var upcoming_shows_string = jsonData["future_shows"].toString().split(":");
        upcoming_shows = double.parse(upcoming_shows_string[1].substring(0,upcoming_shows_string[1].length - 1));

        var upcoming_rsvps_string = jsonData["future_rsvps"].toString().split(":");
        upcoming_rsvps = double.parse(upcoming_rsvps_string[1].substring(0,upcoming_rsvps_string[1].length - 1));

        var trailing_rsvps_string = jsonData["trailing_rsvps"].toString().split(":");
        total_p_rsvps = double.parse(trailing_rsvps_string[1].substring(0,trailing_rsvps_string[1].length - 1));

        var trailing_att_string = jsonData["trailing_att"].toString().split(":");
        total_att = double.parse(trailing_att_string[1].substring(0,trailing_att_string[1].length - 1));

        //note: this is only the last few shows, not a complete history. see php file for more details
        var past_shows_string = jsonData["trailing_shows"].toString().split(":");
        past_shows = double.parse(past_shows_string[0]);

        if(past_shows > 0.0){
          avg_past_rsvps = total_p_rsvps / past_shows;
          avg_attendance = total_att / past_shows;
        }

        if(upcoming_shows > 0.0){
          avg_f_rsvps = upcoming_rsvps / upcoming_shows;
        }

      });
    }

    venue_pull_counter = 1;

  }

  //get local show listview
  Future<List<LocalShow>> getLocalShows()

    async {

      Map<String, String> input_data = {
        "latitude": center.latitude.toString(),
        "longitude": center.longitude.toString(),
        "user_id": args.user_id,
        "user_type" : args.user_type
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
            i["attending_flag"],
            i["audio_link"],
            0);
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

      if(localShows.isNotEmpty) {
        return localShows;
      }
      else{
        return showDialog(
            context: context,
            builder: (context){
              return AlertDialog(title: Text("Uh oh! There aren't shows near you"));
            }
        );
      }


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
                i["under_21_flag"],
                i["bid_amount"],
                i["payment_status"]);
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

        if(myShows.isNotEmpty) {
          return myShows;
        }
        else{
          if(args.user_type == "fan") {
            return showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                      title: Text("Go find shows to attend!"));
                }
            );
          }
          else{
            return showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                      title: Text("Add a show!"));
                }
            );
          }
        }

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

      //functions for fan pressing attend button. Displays dialog for submitting bid

      TextEditingController bidInputController = TextEditingController();

      void OpenBidDialog(user_id_input, show_id_input) async{

        return showDialog(
            context: context,
            builder: (context){
              return AlertDialog(
                title: Text('Show Ticket Bid'),
                content:
                Column(
                children: [
                  Text("You will only be charged if the venue accepts your bid"),
                  TextField(
                    //user inputs bid here
                    onChanged: (value) { setState(() {
                      bidInputController.text = bidInputController.text;
                    }); },
                    controller: bidInputController,
                    decoration: InputDecoration(hintText: "Bid for a ticket"),
                  ),
                  Text(
                    //card processing fee calculated here, ensure this matches php code
                    //calculated based on Stripe's stated pricing
                      (double.parse(bidInputController.text)*0.029+0.30).toString() + "card processing fee"
                  ),
                  Text(
                    //EQO fee calculated here; ensure this matches php code
                    //50% up to $5; 25% on $5-10, 12.5% on $10-20, 10% on $20-40, 5% beyond

                      (min(double.parse(bidInputController.text),5)*0.5
                      +min(max(0,double.parse(bidInputController.text)-5),5)*0.25
                      +min(max(0,double.parse(bidInputController.text)-10),10)*0.125
                      +min(max(0,double.parse(bidInputController.text)-20),20)*0.1
                      +max(0,double.parse(bidInputController.text)-40)*0.05).toString() + "EQO fee"
                  ),
                  Text(
                    //Total (sum of above here)
                    "Total"
                  )]
                ),
              actions: [
                TextButton(
                  onPressed: SubmitBid(user_id_input, show_id_input, bidInputController.value),
                  child: const Text('Submit'),
                ),
              ]
              );
            }
        );

      }

      //functions for fan pressing attend button. Displays dialog for submitting bid

      SubmitBid(user_id_input, show_id_input, bid_value) async {

        Map<String, String> input_bid_data = {
          "user_id": user_id_input,
          "show_id": show_id_input,
          "bid_value": bid_value,
          "status": "0"
        };

        var url_bids = 'https://eqomusic.com/mobile/bid_submit.php';

        var data = await http.post(url_bids,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_bid_data
        );

        if(data.body.contains('Error') == true){
          print(data.body);
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("An error occurred, please try again"));
              }
          );

        }

      }

      //venue accepts bid for ticket, updates payment status for person that payment is needed
      void AttendApproved(user_id_input, show_id_input) async {

        Map<String, String> input_data_attend = {
          "user_id": user_id_input,
          "show_id": show_id_input,
          "attend_approved": "1"
        };

        var url_my_shows = 'https://eqomusic.com/mobile/bid_handling.php';

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

    //function invoked when venue declines a fan's bid; happens upon decision
    //note: the php function keeps the record in the db w a payment status = -1
    //this keeps the data in the db for future use, but ensures the record is no longer shown
    void AttendDeclined(user_id_input, show_id_input) async {

      Map<String, String> input_data_attend = {
        "user_id": user_id_input,
        "show_id": show_id_input,
        "decline_button": "1"
      };

      var url_my_shows = 'https://eqomusic.com/mobile/bid_handling.php';

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
              return AlertDialog(title: Text("An error occurred, please refresh and try again"));
            }
        );

      }

    }

      //function for showing dialog with ticket bids on venue selection

      void OpenBidListDialog(user_id, user_type, user_city, user_state, show_id, artist_1, artist_2, artist_3, year, month_no, day, time, max_attend, genre) async{

        return showDialog(
            context: context,
            builder: (context){
              return AlertDialog(
                  title: Text('Review Ticket Bid'),
                  content:
                  Container(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Review and accept/decline ticket bids for this show"),
                          Expanded(
                            child: FutureBuilder(
                                future: showTicketBids(show_id),
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

                                            key: UniqueKey(),

                                            title: FlatButton(
                                                child:
                                                Row(children: [snapshot.data[int].bid,
                                                    snapshot.data[int].user_f_name,
                                                    snapshot.data[int].user_l_name])),
                                            trailing:
                                                //accept / decline buttons. Will remove row
                                                Row(children: [
                                                  //accept
                                                  GestureDetector(
                                                      child: Icon(Icons.check_circle_outline, color: Colors.green[900]),

                                                      onTap: (){

                                                        //accept bid approval
                                                        AttendApproved(snapshot.data[int].user_id, show_id);

                                                        //remove list tile
                                                        snapshot.data.removeAt(int);
                                                        setState(() {
                                                          snapshot = snapshot.data;
                                                        });

                                                      }
                                                  ),
                                                  //decline
                                                  GestureDetector(
                                                      child: Icon(Icons.cancel_outlined, color: Colors.red[900]),

                                                      onTap: (){

                                                        //decline bid php code
                                                        AttendDeclined(snapshot.data[int].user_id, show_id);

                                                        //remove list tile
                                                        snapshot.data.removeAt(int);
                                                        setState(() {
                                                          snapshot = snapshot.data;
                                                        });

                                                      }
                                                  ),
                                                ]
                                            ));
                                      }
                                  );
                            })
                      )]
                  )),
                  actions: [
                    TextButton(
                      onPressed: //navigate to edit page
                        (){
                        Navigator.pushNamed(
                        context,
                        EventHandling.routeName,
                        arguments: EventInputs(user_id, user_type, user_city, user_state, true, show_id, artist_1, artist_2,
                        artist_3, year, month_no, day, time, max_attend, genre));
                        },
                      child: const Text('Edit/Cancel Show'),
                    )
                  ]
              );
            }
        );

      }

      //function for pulling ticket bids

      Future<List<ShowBid>> showTicketBids(show_id_input) async {

        Map<String, String> input_data_get_bids = {
          "show_id": show_id_input,
        };

        //get data from database

        var url_get_bids = 'https://eqomusic.com/mobile/bid_retrieval.php';

        var data = await http.post(url_get_bids,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_get_bids
        );

        print("my check" + data.body);

        var jsonData = json.decode(data.body);

        List<ShowBid> showBids = [];

        //loop through output
        for (var i in jsonData) {
          ShowBid showBid = ShowBid(
              show_id_input,
              i["user_id"],
              i["user_f_name"],
              i["user_l_name"],
              i["bid"]);
          showBids.add(showBid);

        }

        if(showBids.isNotEmpty) {
          return showBids;
        }
        else{
          return showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                    title: Text("No one has bid for this show"));
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

      //Stripe payment functions

      final HttpsCallable INTENT = CloudFunctions.instance
          .getHttpsCallable(functionName: 'createPaymentIntent');

      //opens payment request form
      startPaymentProcess(show_id, bid) {
        StripePayment.paymentRequestWithCardForm(CardFormPaymentRequest())
            .then((paymentMethod) {
          double amount=bid*100.0; // multiplying by 100 to change $ to cents
          INTENT.call(<String, dynamic>{'amount': amount,'currency':'usd'}).then((response) {
            confirmDialog(response.data["client_secret"],paymentMethod, show_id, bid); //function for confirmation for payment
          });
        });
      }

      //confirm payment view
      confirmDialog(String clientSecret,PaymentMethod paymentMethod, String show_id, double bid) {
        var confirm = AlertDialog(
          title: Text("Confirm Payment"),
          content: Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "Make Payment",
                  // style: TextStyle(fontSize: 25),
                ),
                Text("Charge amount:\$100")
              ],
            ),
          ),
          actions: <Widget>[
            new RaisedButton(
              child: new Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
                final snackBar = SnackBar(content: Text('Payment Cancelled'),);
                Scaffold.of(context).showSnackBar(snackBar);
              },
            ),
            new RaisedButton(
              child: new Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                confirmPayment(clientSecret, paymentMethod, show_id, bid); // function to confirm Payment
              },
            ),
          ],
        );
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return confirm;
            });
      }

      //function to confirm payment
      confirmPayment(String sec, PaymentMethod paymentMethod, String show_id, double bid) {
        StripePayment.confirmPaymentIntent(
          PaymentIntent(clientSecret: sec, paymentMethodId: paymentMethod.id),
        ).then((val) {
          updatePaymentStatus(show_id, bid); //confirm payment status function
          final snackBar = SnackBar(content: Text('Payment Successful'),);
          Scaffold.of(context).showSnackBar(snackBar);
        });
      }

      //function to update payment status, send email
      void updatePaymentStatus(show_id, bid) async {

        Map<String, String> input_data_payment = {
          "user_id" : args.user_id,
          "show_id" : show_id,
          "bid_value": bid,
        };

        var url_payment_update = 'https://eqomusic.com/mobile/payment_status_update.php';

        var data = await http.post(url_payment_update,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_payment
        );

        if(data.body.contains('Error') == true){
          print(data.body);
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("There was an issue generating the receipt"));
              }
          );

        }

      }

    //******************************************************************************************************************
    //Start of the app UI build
    //******************************************************************************************************************


      @override
      Widget build(BuildContext context) {

        if(args.user_type == "venue"){
          fab_visibility = true;
        }

        _getCurrentLocation();

        if(args.user_type == "venue" && venue_pull_counter<1) {
          VenueInfo();
        }

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
                      actions: (args.user_type != "fan") && (args.user_type != "venue") ? null : [
                        IconButton(
                          icon: Icon(
                            Icons.settings,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if(args.user_type == "fan") {
                              //go to payment screen for fans for management
                              Navigator.pushNamed(
                                  context,
                                  VenueSettings.routeName,
                                  arguments: LoginOutput(
                                      args.user_id, args.user_type,
                                      args.user_city, args.user_state,
                                      args.subscription_flag,
                                      args.final_month_flag));
                            }
                            else{
                              //go to settings for venue to adjust address/name/etc.
                              Navigator.pushNamed(
                                  context,
                                  VenueSettings.routeName,
                                  arguments: LoginOutput(
                                      args.user_id, args.user_type,
                                      args.user_city, args.user_state,
                                      args.subscription_flag,
                                      args.final_month_flag));
                            }
                          },
                        )
                      ]
                  ),
                  body: TabBarView(
                      children: [(

                          Expanded( child: Column( children:[

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
                                  Wrap(
                                      spacing:12,
                                      children: [
                                          snapshot.data[int].audio_link == "" ?
                                          SizedBox.shrink()
                                          :
                                          GestureDetector(child: Icon(Icons.play_circle_fill, color: snapshot.data[int].row_play_pause == 0 ? Colors.green: Colors.red),
                                              onTap: (){

                                                  //logic: if music is not being played, turn button red and play audio
                                                  //logic: if music is not being played, then see below:
                                                  //sub-logic: if button is green -> turn all buttons green, play new song, turn button red, play_pause = 1

                                                  if(play_pause_flag == 0){

                                                      //case where music is not being played (start playing audio)

                                                      audioPlayer.play(snapshot.data[int].audio_link);

                                                      setState(() {
                                                      snapshot.data[int].row_play_pause = 1;
                                                      play_pause_flag = 1;
                                                      });
                                                  }

                                                  else{

                                                      //case where music is being played from the same row in which the button is pressed (simple pause)

                                                      if(snapshot.data[int].row_play_pause == 1){

                                                      audioPlayer.pause();

                                                      setState(() {
                                                      snapshot.data[int].row_play_pause = 0;
                                                      play_pause_flag = 0;
                                                      });

                                                      }

                                                      else{

                                                          //case where music is being played from a different row (need to reset all buttons, pause audio stream, then play new music

                                                          audioPlayer.pause();
                                                          audioPlayer.play(snapshot.data[int].audio_link);

                                                          setState(() {

                                                              for(var i = 0; i<=int; i++){
                                                              snapshot.data[i].row_play_pause = 0;
                                                          }

                                                          snapshot.data[int].row_play_pause = 1;
                                                          play_pause_flag = 1;

                                                          });

                                                      }
                                                  }
                                          }),
                                          //keeps attendance buttons for fans only
                                          args.user_type != "fan"?
                                          SizedBox.shrink()
                                          :
                                          snapshot.data[int].attending_flag == 1?
                                          Icon(Icons.check_circle_outline, color: Colors.green)
                                          : GestureDetector(child: Icon(Icons.control_point_rounded, color: Colors.orange),

                                                onTap: (){
                                                my_show_map_update_counter = 0;
                                                String user_id_input = args.user_id;
                                                String show_id_input = snapshot.data[int].show_id;
                                                OpenBidDialog(user_id_input, show_id_input);
                                                setState(() {
                                                  Icon(Icons.check_circle_outline, color: Colors.green);
                                                });
                                                }
                                          )
                                      ]
                                  )

                          );
                        },
                      );
                    },
                  )),



              ]))),

                        (

                            Column(children:[

                              Container(
                                  height:250,
                                  child:(

                                      //map is for fans only; dashboard view for venues put in place

                                      args.user_type == "fan" ?

                                      GoogleMap(
                                        markers: myShowMarkers,
                                        onMapCreated: _onMyShowMapCreated,
                                        myLocationEnabled: true,
                                        initialCameraPosition: CameraPosition(
                                          target: center,
                                          zoom: 11.0,
                                        ),
                                      )

                                          :

                                      Column(

                                          children: [

                                            SizedBox(height: 30.0),

                                            Expanded(
                                                flex: 10,
                                                child: GridView.count(
                                                    crossAxisCount: 2,
                                                    childAspectRatio: 3,
                                                    padding: const EdgeInsets.all(1.0),
                                                    mainAxisSpacing: 0,
                                                    crossAxisSpacing: 10.0,
                                                    physics: NeverScrollableScrollPhysics(),
                                                    shrinkWrap: true,
                                                    children: [
                                                      Align(alignment: Alignment.center, child: Text("Last 5 Shows Averages", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                                      Align(alignment: Alignment.center, child: Text("Upcoming", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                                      Align(alignment: Alignment.center, child: Text(avg_past_rsvps.toString() + " RSVPs", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15))),
                                                      Align(alignment: Alignment.center, child: Text(avg_f_rsvps.toString() + " Avg. RSVPs", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15))),
                                                      Align(alignment: Alignment.center, child: Text(avg_attendance.toString() + " Actual Attendance", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15))),
                                                      Align(alignment: Alignment.center, child: Text(upcoming_shows.toString() + " Upcoming Shows", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15))),
                                                    ]
                                                )
                                            ),

                                          ])

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
                                              //adds button for paying/declining RSVP (fans) or reviewing bids/editing/canceling event (venues)
                                              GestureDetector(

                                                //need to adjust based on status. Paid (2) -> green, payment needed (1) -> yellow, pending (0) -> grey
                                                //only allow click if yellow
                                                child: args.user_type == "venue" ? Text ("Review Bids") :

                                                    snapshot.data[int].payment_status == 0 ? Icon(Icons.event_outlined, color: Colors.grey[450]) :

                                                        snapshot.data[int].payment_status == 1 ? Icon(Icons.event_outlined, color: Colors.yellow[800]) :

                                                            Icon(Icons.event_outlined, color: Colors.green[900]),

                                                  //alternative for reviewing bids for venues
                                                //Icon(Icons.attach_money_outlined, color: Colors.green[900]),

                                                onTap: (){

                                                  my_show_map_update_counter = 0;

                                                  if(args.user_type == "fan" && snapshot.data[int].payment_status == "1"){

                                                    //launch payment dialog info. Pre-load bid amounts so it can feed into Stripe directly
                                                    //show fee breakdown: $x for bid, stripe fee, EQO fee (max? %? TBD)
                                                    //make sure to send an email receipt and that the future build is redone so that the icon becomes green

                                                    //note: this asks for card input, confirms amount, then submits payment
                                                    startPaymentProcess(snapshot.data[int].show_id, snapshot.data[int].bid_amount.todouble());

                                                  }

                                                  else if(args.user_type == "venue"){
                                                    //button for opening dialog w/ ticket info & edit/cancel button, has to pass info from row to navigator

                                                    OpenBidListDialog(args.user_id, args.user_type, args.user_city, args.user_city, snapshot.data[int].show_id, snapshot.data[int].artist_1, snapshot.data[int].artist_2,
                                                        snapshot.data[int].artist_3, snapshot.data[int].year, snapshot.data[int].month_no, snapshot.data[int].day, snapshot.data[int].time, snapshot.data[int].max_attend, snapshot.data[int].genre);

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

                                              //QR code area
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

                  ),

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
  bool get wantKeepAlive => true; //throw UnimplementedError();

      }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

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
  final String audio_link;
  final int row_play_pause;

  LocalShow(this.show_id, this.venue, this.genre, this.time,
      this.month, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.under_21_flag, this.attending_flag, this.audio_link, this.row_play_pause);

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
  final String bid_amount;
  final String payment_status;

  MyShow(this.show_id, this.venue, this.genre, this.time, this.year,
      this.month, this.month_no, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.ticket_color, this.ticket_icon, this.under_21_flag, this.bid_amount, this.payment_status);

}

class ShowBid {
  final String show_id;
  final String user_id;
  final String user_f_name;
  final String user_l_name;
  final String ticket_bid;

  ShowBid(this.show_id, this.user_id, this.user_f_name, this.user_l_name, this.ticket_bid);

}