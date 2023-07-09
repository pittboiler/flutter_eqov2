import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_eqo_v2/event_handling.dart';
import 'package:flutter_eqo_v2/login.dart';
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
        ScanQR.routeName: (context) => ScanQR(),
      },
      initialRoute: "/",
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
  int row_pp_button = -1;

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

  final Geolocator geolocator = Geolocator()..forceAndroidLocationManager;

  //counters for modals so that they are not repeated
  int add_show_modal_counter  = 0;
  int no_shows_modal_counter  = 0;
  int find_show_modal_counter = 0;

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
        "latitude": args.center.latitude.toString(),
        "longitude": args.center.longitude.toString(),
        "user_id": args.user_id,
        "user_type" : args.user_type
      };

      print("check this data for location" + input_data.toString());

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
      int row_counter = 0;

      for (var i in jsonData) {

        print(row_pp_button.toString() + " should match " + row_counter.toString());

        if(row_pp_button == row_counter){
          row_pp_button = 1;
        }

        print(row_pp_button);

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
            row_pp_button);
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

        row_counter = row_counter + 1;

      }

      //update map with markers once
      if(map_update_counter < 1 && localShows.isNotEmpty) {
        setState(() {
          localMarkers;
        });
        map_update_counter = map_update_counter + 1;
      };

      if(localShows.isNotEmpty) {
        return localShows;
      }
      else{
        if(no_shows_modal_counter == 0)
          {
            no_shows_modal_counter = no_shows_modal_counter+1;
            return showDialog(
                context: context,
                builder: (context){
                  return AlertDialog(title: Text("Uh oh! There aren't shows near you"));
                }
            );
          }
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

        var url_my_shows = 'https://eqomusic.com/mobile/my_show_display_vbid.php';

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
                i["bid_value"],
                i["credit_card_fee"],
                i["eqo_fee"],
                i["total_order"],
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
          if (my_show_map_update_counter < 1 && myShows.isNotEmpty) {
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
            if(find_show_modal_counter == 0){
              find_show_modal_counter = find_show_modal_counter + 1;
              return showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                        title: Text("Go find shows to attend!"));
                  }
              );
            }
          }
          else{
            if(add_show_modal_counter == 0){
              add_show_modal_counter = add_show_modal_counter + 1;
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
      TextEditingController quantityInputController = TextEditingController();

      Future OpenBidDialog(user_id_input, show_id_input, context) async{

        return showDialog(
            context: context,
            builder: (context){

              //initializes variables for bid systems
              double typed_bid       = 0;
              double credit_card_fee = 0;
              double eqo_fee         = 0;
              double total_order     = 0;

              return AlertDialog(
                title: Text('Show Ticket Bid'),
                content: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState){
                    return Column(
                        children: [
                          Text("You will only be charged if the venue accepts your bid"),
                          TextField(
                            keyboardType: TextInputType.number,
                            //user inputs bid here; on change, updates the variables to fill in the other data
                            onChanged: (value) { setState(() {

                              typed_bid = double.parse(bidInputController.text.replaceAll(RegExp('\$'), ''));

                              //card processing fee calculated here
                              //calculated based on Stripe's stated pricing
                              credit_card_fee = typed_bid*0.029+0.30;

                              print("this is the cc fee: " + credit_card_fee.toString());

                              //EQO fee calculated here
                              //50% up to $5; 25% on $5-10, 12.5% on $10-20, 10% on $20-40, 5% beyond
                              eqo_fee         = min(typed_bid,5)*0.5 +
                                  min(max(0,typed_bid-5),5)*0.25 +
                                  min(max(0,typed_bid-10),10)*0.125 +
                                  min(max(0,typed_bid-20),20)*0.1 +
                                  max(0,typed_bid-40)*0.0;

                              print("this is the EQO fee: " + eqo_fee.toString());

                              //sum of bid + cc fee + eqo fee
                              total_order      = typed_bid + credit_card_fee + eqo_fee;

                              print("this is the total order: " + total_order.toString());

                            }); },
                            controller: bidInputController,
                            decoration: InputDecoration(hintText: "Type a number as your bid"),
                          ),
                          Text(
                            //card processing fee
                              "\$" + credit_card_fee.toStringAsFixed(2) + " card processing fee"
                          ),
                          Text(
                            //EQO fee
                              "\$" + eqo_fee.toStringAsFixed(2) + " EQO fee"
                          ),
                          Text(
                            //Total
                              "\$" + total_order.toStringAsFixed(2) + " Total"
                          )]
                    );
                  }
                ),
                  actions: [
                    TextButton(
                      onPressed: () => SubmitBid(user_id_input, show_id_input, typed_bid, credit_card_fee, eqo_fee, total_order),
                      child: const Text('Submit'),
                    ),
                  ]
              );
            }
        );

      }

      //functions for fan pressing attend button. Displays dialog for submitting bid

      Future SubmitBid(user_id_input, show_id_input, bid_value, credit_card_fee, eqo_fee, total_order) async {

        Map<String, String> input_bid_data = {
          "user_id": user_id_input,
          "show_id": show_id_input,
          "bid_value": bid_value.toString(),
          "cc_fee"   : credit_card_fee.toString(),
          "eqo_fee"  : eqo_fee.toString(),
          "total_amt": total_order.toString(),
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
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("An error occurred, please try again"));
              }
          );

        }

        else{
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("Bid submitted!"));
              }
          );
        }

      }

      //venue accepts bid for ticket, updates payment status for person that payment is needed
      Future AttendApproved(user_id_input, show_id_input) async {

        Map<String, String> input_data_attend = {
          "user_id": user_id_input,
          "show_id": show_id_input,
          "attend_button": "1"
        };

        var url_approved = 'https://eqomusic.com/mobile/bid_handling.php';

        var data = await http.post(url_approved,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_attend
        );

        print(input_data_attend.toString());

        print(data.body);

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
    Future AttendDeclined(user_id_input, show_id_input) async {

      print("is this being called?");

      Map<String, String> input_data_attend = {
        "user_id": user_id_input,
        "show_id": show_id_input,
        "decline_button": "1"
      };

      var url_declined = 'https://eqomusic.com/mobile/bid_handling.php';

      var data = await http.post(url_declined,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: input_data_attend
      );

      print(input_data_attend);
      print(data.body);

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

      Future OpenBidListDialog(BuildContext context, user_id, user_type, user_city, user_state, show_id, artist_1, artist_2, artist_3, year, month_no, day, time, max_attend, genre) async{

        print("this was called for show ID " + show_id);

        return showDialog(
            context: context,
            useRootNavigator: false,
            builder: (BuildContext context){
              return AlertDialog(
                  title: Text('Review Ticket Bid'),
                  content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                    return Container(
                        width: double.maxFinite,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  "Review and accept/decline ticket bids for this show"),
                              Expanded(
                                  child: FutureBuilder(
                                      future: showTicketBids(show_id),
                                      builder: (BuildContext context,
                                          AsyncSnapshot snapshot) {
                                        if (snapshot.data == null) {
                                          return Container(
                                              child: Center(
                                                  child: new CircularProgressIndicator()
                                              )
                                          );
                                        }

                                        return ListView.builder(
                                            itemCount: snapshot.data.length,
                                            itemBuilder: (context, int) {
                                              return ListTile(

                                                  key: UniqueKey(),

                                                  title: FlatButton(
                                                      child:
                                                      Row(children: [
                                                        Text(snapshot.data[int]
                                                            .bid_value),
                                                        Text(snapshot.data[int]
                                                            .first_name),
                                                        Text(snapshot.data[int]
                                                            .last_name)
                                                      ])),
                                                  trailing:
                                                  SizedBox(
                                                      width: 100,
                                                      //accept / decline buttons. Will remove row
                                                      child: Row(children: [
                                                        //accept
                                                        GestureDetector(
                                                            child: Icon(Icons
                                                                .check_circle_outline,
                                                                color: Colors
                                                                    .green[900]),

                                                            onTap: () {
                                                              //accept bid approval
                                                              AttendApproved(
                                                                  snapshot
                                                                      .data[int]
                                                                      .user_id,
                                                                  show_id);

                                                              //remove list tile
                                                              Future.delayed(const Duration(milliseconds: 100), () {
                                                                setState(() {
                                                                });
                                                              });
                                                            }
                                                        ),

                                                        Text("    "),
                                                        //decline
                                                        GestureDetector(
                                                            child: Icon(Icons.cancel_outlined, color: Colors.red[900]),

                                                            onTap: () {
                                                              //decline bid php code
                                                              AttendDeclined(snapshot.data[int].user_id, show_id);

                                                              //remove list tile
                                                              Future.delayed(const Duration(milliseconds: 100), () {
                                                                setState(() {
                                                                });
                                                              });
                                                            }
                                                        ),
                                                      ]
                                                      )));
                                            }
                                        );
                                      })
                              )
                            ]
                        ));
                  }),
                  actions: [
                    TextButton(
                      onPressed: //navigate to edit page
                        (){
                        Navigator.pushNamed(
                        context,
                        EventHandling.routeName,
                        arguments: EventInputs(user_id, user_type, user_city, user_state, true, show_id, artist_1, artist_2,
                        artist_3, year, month_no, day, time, max_attend, genre, args.center));
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

        print("we have bids!");

        List<ShowBid> showBids = [];

        //loop through output
        for (var i in jsonData) {
          ShowBid showBid = ShowBid(
              show_id_input,
              i["user_id"],
              i["first_name"],
              i["last_name"],
              i["bid_value"]);
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

        var url_cancel = 'https://eqomusic.com/mobile/attendance_management_vbid.php';

        var data = await http.post(url_cancel,
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
      startPaymentProcess(show_id, bid, credit_card_fee, eqo_fee, total_order) {
        StripePayment.paymentRequestWithCardForm(CardFormPaymentRequest())
            .then((paymentMethod) {
          double total_amount=double.parse(total_order)*100.0;
          String amount = total_amount.toStringAsFixed(0); // multiplying by 100 to change $ to cents

          //fix flow through for UI purposes only
          eqo_fee         = double.parse(eqo_fee).toStringAsFixed(2);
          credit_card_fee = double.parse(credit_card_fee).toStringAsFixed(2);
          total_order     = double.parse(total_order).toStringAsFixed(2);

          INTENT.call(<String, dynamic>{'amount': amount,'currency':'usd'}).then((response) {
            confirmDialog(response.data['client_secret'], paymentMethod, show_id, bid, credit_card_fee, eqo_fee, total_order); //function for confirmation for payment
          });
        });
      }

      //confirm payment view
      confirmDialog(String clientSecret,PaymentMethod paymentMethod, String show_id, bid, credit_card_fee, eqo_fee, total_order) {
        var confirm = AlertDialog(
          title: Text("Confirm Payment"),
          content: Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text("Make Payment", style: TextStyle(fontSize: 25)),
                Text(bid.toString() + " bid amount"),
                Text(credit_card_fee.toString() + " credit card fee"),
                Text(eqo_fee.toString() + " EQO fee"),
                Text(total_order.toString() + " Total order", style: const TextStyle(fontWeight: FontWeight.bold))
              ],
            ),
          ),
          actions: <Widget>[
            new RaisedButton(
              child: new Text('Cancel'),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop('dialog');
              },
            ),
            new RaisedButton(
              child: new Text('Confirm'),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop('dialog');
                confirmPayment(clientSecret, paymentMethod, show_id, bid, credit_card_fee, eqo_fee, total_order); // function to confirm Payment
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
      confirmPayment(String sec, PaymentMethod paymentMethod, String show_id, bid, credit_card_fee, eqo_fee, total_order) {
        StripePayment.confirmPaymentIntent(
          PaymentIntent(clientSecret: sec, paymentMethodId: paymentMethod.id),
        ).then((val) {
          updatePaymentStatus(show_id, bid, credit_card_fee, eqo_fee, total_order); //confirm payment status function
          final snackBar = SnackBar(content: Text('Payment Successful'),);
          Scaffold.of(context).showSnackBar(snackBar);
        });
      }

      //function to update payment status, send email
      void updatePaymentStatus(show_id, String bid, String credit_card_fee, String  eqo_fee, String total_order) async {

        Map<String, String> input_data_payment = {
          "user_id" : args.user_id,
          "show_id" : show_id,
          "bid_value": bid,
          "cc_fee"  : credit_card_fee,
          "eqo_fee" : eqo_fee,
          "total_order" : total_order,

        };

        var url_payment_update = 'https://eqomusic.com/mobile/payment_status_update.php';

        var data = await http.post(url_payment_update,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: input_data_payment
        );

        print("this is reading data:" + data.body);

        if(data.body.contains('Error') == true){
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("There was an issue generating the receipt"));
              }
          );
        }
        else{
          setState(() {
          });
          return showDialog(
              context: context,
              builder: (context){
                return AlertDialog(title: Text("You're going!"));
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
                                      args.center));
                            }
                            else{
                              //go to settings for venue to adjust address/name/etc.
                              Navigator.pushNamed(
                                  context,
                                  VenueSettings.routeName,
                                  arguments: LoginOutput(
                                      args.user_id, args.user_type,
                                      args.user_city, args.user_state,
                                      args.center));
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
                                        target: args.center,
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
                                                      crossAxisCount: 2,
                                                      childAspectRatio: 2.5,
                                                      padding: const EdgeInsets.all(1.0),
                                                      mainAxisSpacing: 0,
                                                      crossAxisSpacing: 10.0,
                                                      physics: NeverScrollableScrollPhysics(),
                                                      shrinkWrap: true,
                                                      children: [
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].venue, textAlign: TextAlign.center)),
                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].genre, textAlign: TextAlign.center)),

                                                        //removed age limit - felt unnecessary, out of purview
                                                        //snapshot.data[int].under_21_flag == "0"?
                                                        //Align(alignment: Alignment.center, child: Text("18+", textAlign: TextAlign.center))
                                                        //    :
                                                        //Align(alignment: Alignment.center, child: Text("21+", textAlign: TextAlign.center)),
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
                                          GestureDetector(child: Icon(Icons.play_circle_fill, color: snapshot.data[int].row_play_pause == -1 ? Colors.green: Colors.red),
                                              onTap: (){

                                                  print("play_pause_flag " + play_pause_flag.toString() + " row pp button " + snapshot.data[int].row_play_pause.toString());

                                                  //logic: if music is not being played, turn button red and play audio
                                                  //logic: if music is not being played, then see below:
                                                  //sub-logic: if button is green -> turn all buttons green, play new song, turn button red, play_pause = 1

                                                  if(play_pause_flag == 0){

                                                      //case where music is not being played (start playing audio)

                                                      audioPlayer.play(snapshot.data[int].audio_link);

                                                      print("this should play!");

                                                      setState(() {
                                                      row_pp_button = int;
                                                      play_pause_flag = 1;
                                                      });

                                                      audioPlayer.onPlayerCompletion.listen((event) {

                                                        setState(() {
                                                          row_pp_button = -1;
                                                          play_pause_flag = 0;
                                                        });

                                                      });

                                                  }

                                                  else{

                                                      //case where music is being played from the same row in which the button is pressed (simple pause)

                                                      if(snapshot.data[int].row_play_pause == 1){

                                                      audioPlayer.stop();

                                                      print("this should stop!");

                                                      setState(() {
                                                      row_pp_button = -1;
                                                      play_pause_flag = 0;
                                                      });

                                                      }

                                                      else{

                                                          //case where music is being played from a different row (need to reset all buttons, pause audio stream, then play new music

                                                          audioPlayer.stop();
                                                          audioPlayer.play(snapshot.data[int].audio_link);

                                                          setState(() {

                                                              for(var i = 0; i<=int; i++){
                                                              snapshot.data[i].row_play_pause = -1;
                                                          }

                                                          row_pp_button = int;
                                                          play_pause_flag = 1;

                                                          });

                                                          audioPlayer.onPlayerCompletion.listen((event) {

                                                            setState(() {
                                                              row_pp_button = -1;
                                                              play_pause_flag = 0;
                                                            });

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

                                                onTap: () => OpenBidDialog(args.user_id, snapshot.data[int].show_id, context),
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
                                          target: args.center,
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
                                                                      crossAxisCount: 2,
                                                                      childAspectRatio: 2.5,
                                                                      padding: const EdgeInsets.all(1.0),
                                                                      mainAxisSpacing: 0,
                                                                      crossAxisSpacing: 10.0,
                                                                      physics: NeverScrollableScrollPhysics(),
                                                                      shrinkWrap: true,
                                                                      children: [
                                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].venue, textAlign: TextAlign.center)),
                                                                        Align(alignment: Alignment.center, child: Text(snapshot.data[int].genre, textAlign: TextAlign.center)),

                                                                        //removed age limit - felt unnecessary, out of purview
                                                                        //snapshot.data[int].under_21_flag == "0"?
                                                                        //Align(alignment: Alignment.center, child: Text("18+", textAlign: TextAlign.center))
                                                                        //    :
                                                                        //Align(alignment: Alignment.center, child: Text("21+", textAlign: TextAlign.center)),
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

                                                    snapshot.data[int].payment_status == "0" ? Icon(Icons.event_outlined, color: Colors.grey[450]) :

                                                        snapshot.data[int].payment_status == "1" ? Icon(Icons.event_outlined, color: Colors.yellow[800]) :

                                                            Icon(Icons.event_outlined, color: Colors.green[700]),

                                                  //alternative for reviewing bids for venues
                                                //Icon(Icons.attach_money_outlined, color: Colors.green[900]),

                                                onTap: (){

                                                  my_show_map_update_counter = 0;

                                                  if(args.user_type == "fan" && snapshot.data[int].payment_status == "1"){

                                                    //launch payment dialog info. Pre-load bid amounts so it can feed into Stripe directly
                                                    //note: this asks for card input, confirms amount, then submits payment

                                                    startPaymentProcess(snapshot.data[int].show_id, snapshot.data[int].bid_value, snapshot.data[int].credit_card_fee,
                                                        snapshot.data[int].eqo_fee, snapshot.data[int].total_order);

                                                  }

                                                  else if(args.user_type == "venue"){
                                                    //button for opening dialog w/ ticket info & edit/cancel button, has to pass info from row to navigator

                                                    OpenBidListDialog(context, args.user_id, args.user_type, args.user_city, args.user_city, snapshot.data[int].show_id, snapshot.data[int].artist_1, snapshot.data[int].artist_2,
                                                        snapshot.data[int].artist_3, snapshot.data[int].year, snapshot.data[int].month_no, snapshot.data[int].day, snapshot.data[int].time, snapshot.data[int].max_attend, snapshot.data[int].genre);

                                                  }

                                                  //updates ticket/scanner button visibility variable based on time to expand QR code

                                                  var now = new DateTime.now();

                                                  if((args.user_type == "venue") & (now.month == double.parse(snapshot.data[int].month_no)) & (now.day == double.parse(snapshot.data[int].day)) /*& ((now.hour-13) >= snapshot.data[int].time)*/){

                                                    switch(scanner_button_visibility){
                                                      case false: {scanner_button_visibility = true;}
                                                      break;
                                                      case true: {scanner_button_visibility = false;}
                                                      break;
                                                    }

                                                  }

                                                  if((args.user_type == "fan") & (now.month == double.parse(snapshot.data[int].month_no)) & (now.day == double.parse(snapshot.data[int].day)) /*& ((now.hour-13) >= snapshot.data[int].time)*/){

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
                                                child:
                                                Center(
                                                  child: QrImage(
                                                    data: args.user_id + "#" + snapshot.data[int].show_id + "#",
                                                    version: QrVersions.auto,
                                                    size: 200.0,
                                                  ),
                                                )
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
                            arguments: EventInputs(args.user_id, args.user_type, args.user_city, args.user_state, false, "", "", "", "", "", "", "", "", "", "", args.center));

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
  int row_play_pause;

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
  final String bid_value;
  final String credit_card_fee;
  final String eqo_fee;
  final String total_order;
  final String payment_status;

  MyShow(this.show_id, this.venue, this.genre, this.time, this.year,
      this.month, this.month_no, this.day, this.artist_1, this.artist_2, this.artist_3,
      this.max_attend, this.venue_address, this.venue_zip_code, this.ticket_color, this.ticket_icon, this.under_21_flag,
      this.bid_value, this.credit_card_fee, this.eqo_fee, this.total_order, this.payment_status);

}

class ShowBid {
  final String show_id;
  final String user_id;
  final String first_name;
  final String last_name;
  final String bid_value;

  ShowBid(this.show_id, this.user_id, this.first_name, this.last_name, this.bid_value);

}