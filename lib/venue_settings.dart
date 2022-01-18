import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/login.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_typeahead/cupertino_flutter_typeahead.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(VenueSettings());

class VenueSettings extends StatelessWidget {

  static const routeName = '/VenueSettingsRoute';

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
      home: VenueSettingsPage(args: args),
      routes: {
        MyApp.routeName: (context) => MyApp(),
      },
    );
  }
}

class VenueSettingsPage extends StatefulWidget {
  VenueSettingsPage({Key key, this.title, @required this.args}) : super(key: key);

  final String title;
  final LoginOutput args;

  @override
  _MyEventFormState createState() => _MyEventFormState(args);
}

class _MyEventFormState extends State<VenueSettingsPage> {

  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  LoginOutput args;

  _MyEventFormState(LoginOutput args) {
    this.args = args;
  }

  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);


  TextEditingController venueNameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController zipController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController venueTypeController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    venueNameController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    zipController.dispose();
    emailController.dispose();
    venueTypeController.dispose();
    super.dispose();
  }

  //FUNCTIONS HAVE NOT YET BEEN TESTED

  //function for pulling data

  int venue_pull_counter = 0;

  Future<void> VenueSettingsInfo()

  async {

    Map<String, String> venue_id_lookup = {
      "function": "pull",
      "user_id" : args.user_id,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/venue_settings_handling.php';

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
        venueNameController = TextEditingController(text: "");
        addressController   = TextEditingController(text: "");
        cityController      = TextEditingController(text: "");
        stateController     = TextEditingController(text: "");
        zipController       = TextEditingController(text: "");
        emailController     = TextEditingController(text: "");
        venueTypeController = TextEditingController(text: "");
      });
    }
    else{
      setState(() {
        print("check" + jsonData.toString());
        venueNameController = TextEditingController(text: jsonData[0]);
        addressController   = TextEditingController(text: jsonData[1]);
        cityController      = TextEditingController(text: jsonData[2]);
        stateController     = TextEditingController(text: jsonData[3]);
        zipController       = TextEditingController(text: jsonData[4]);
        emailController     = TextEditingController(text: jsonData[5]);
        venueTypeController = TextEditingController(text: jsonData[6]);
      });
    }

    venue_pull_counter = 1;

  }

  Future<void> UpdateVenueSettings(venueName, address, city, state, zipCode, email, venueType)

  async {

    Map<String, String> data_submission = {
      "function": "update",
      "user_id" : args.user_id,
      "venueName" : venueName,
      "address" : address,
      "city"    : city,
      "state"   : state,
      "zip_code": zipCode,
      "email"   : email,
      "venueType" : venueType,
    };

    //put data into data from database

    var url_login = 'https://eqomusic.com/mobile/venue_settings_handling.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: data_submission
    );

    var jsonData = json.decode(data.body);

    print(jsonData);

    if(data.body.contains('Error') == true){

      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(title: Text("Could not update settings; please check connection and try again"));
          }
      );

    }
    else{

      Navigator.pushNamed(
          context,
          MyApp.routeName,
          arguments: LoginOutput(args.user_id, args.user_type, args.user_city, args.user_state, "1", "0"));

    }

  }

  //function for updating venue data

  //******************************************************************************************************************
  //Start of the app UI build
  //******************************************************************************************************************

  @override
  Widget build(BuildContext context) {

    if(venue_pull_counter<1){
      VenueSettingsInfo();
    }

    final venueNameField = TextField(
      style: style,
      controller: venueNameController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Venue Name",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final addressField = TextField(
      style: style,
      controller: addressController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Genre",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final cityField = TextField(
      style: style,
      controller: cityController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "City",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final stateField = TextField(
      style: style,
      controller: stateController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "State",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final zipField = TextField(
      style: style,
      controller: zipController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "ZIP Code",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final emailField = TextField(
      style: style,
      controller: emailController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Email",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final venueTypeField = TextField(
      style: style,
      controller: venueTypeController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Venue Type",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final updateButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {

          UpdateVenueSettings(venueNameController.text, addressController.text, cityController.text, stateController.text, zipController.text, emailController.text, venueTypeController.text);

        },
        child: Text("Update Info",
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
                    venueNameField,
                    SizedBox(height: 25.0),
                    addressField,
                    SizedBox(height: 25.0),
                    cityField,
                    SizedBox(height: 25.0),
                    stateField,
                    SizedBox(height: 25.0),
                    zipField,
                    SizedBox(height: 25.0),
                    emailField,
                    SizedBox(height: 25.0),
                    venueTypeField,
                    SizedBox(height: 25.0),
                    updateButon,
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}