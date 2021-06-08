import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/login.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'package:flutter_eqo_v2/artist_main.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';

void main() => runApp(MyRegister());

class MyRegister extends StatelessWidget {
  static const routeName = '/RegisterRoute';
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EQO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyRegisterPage(title: 'Flutter Login'),
    );
  }
}

class MyRegisterPage extends StatefulWidget {
  MyRegisterPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyRegisterPage> {
  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  //form handling controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();

  final fnameController = TextEditingController();
  final lnameController = TextEditingController();
  final vnameController = TextEditingController();
  final fandobController = MaskedTextController(mask: "00/00/0000");

  final fanlocationController = TextEditingController();
  final addressController = TextEditingController();
  final artistlocationController = TextEditingController();
  final zipController = TextEditingController();

  final vtypeController = TextEditingController();
  final artistnameController = TextEditingController();
  final artistgenreController = TextEditingController();

  //radio button and field display handling
  int radioValue1 = -1;
  bool typeChosen = false;
  bool fanChosen = false;
  bool venueChosen = false;
  bool artistChosen = false;

  void _handleRadioValueChange1(int value) {
    setState(() {
      radioValue1 = value;
      typeChosen = true;
      if(radioValue1 == 1){
        fanChosen = true;
        venueChosen = false;
        artistChosen = false;
      }
      else {
        if(radioValue1 == 2){
          venueChosen = true;
          fanChosen = false;
          artistChosen = false;
        }
        else{
          artistChosen = true;
          venueChosen = false;
          fanChosen = false;
        }
      }
    });
  }

  //core register functions

  //fan register: take inputs from login field, run by code validation, output login info or error message
  Future<List<LoginOutput>> RegisterFan(input_email, input_password, input_fname, input_lname, input_city, input_state, input_dob)

  async {

    Map<String, String> input_data_register_fan = {
      "switch_fan" : "yes",
      "email": input_email,
      "password" : input_password,
      "first_name" : input_fname,
      "last_name" : input_lname,
      "city" : input_city,
      "state" : input_state,
      "date_of_birth" : input_dob,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/sign_up.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_data_register_fan
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
          arguments: LoginOutput(jsonData[0].toString(), jsonData[1].toString(), jsonData[2].toString(), jsonData[3].toString(), jsonData[4].toString(), jsonData[5].toString()));
    }

  }

  //venue register: take inputs from login field, run by code validation, output login info or error message
  Future<List<LoginOutput>> RegisterVenue(input_email, input_password, input_vname, input_address, input_city, input_state, input_zip, input_vtype)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_data_register_venue = {
      "switch_venue" : "yes",
      "email": input_email,
      "password" : input_password,
      "venue_name" : input_vname,
      "address" : input_address,
      "address_zip_code" : input_zip,
      "city" : input_city,
      "state" : input_state,
      "venue_type" : input_vtype,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/sign_up.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_data_register_venue
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
          arguments: LoginOutput(jsonData[0].toString(), jsonData[1].toString(), jsonData[2].toString(), jsonData[3].toString(), jsonData[4].toString(), jsonData[5].toString()));
    }

  }

  //artist register: take inputs from login field, run by code validation, output login info or error message
  Future<List<LoginOutput>> RegisterArtist(input_email, input_password, input_aname, input_genre, input_city, input_state)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_data_register_venue = {
      "switch_artist" : "yes",
      "email": input_email,
      "password" : input_password,
      "artist_name" : input_aname,
      "artist_genre" : input_genre,
      "city" : input_city,
      "state" : input_state,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/sign_up.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_data_register_venue
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
              ArtistMain.routeName,
              arguments: LoginOutput(jsonData[0].toString(), jsonData[1].toString(), jsonData[2].toString(), jsonData[3].toString(), jsonData[4].toString(), jsonData[5].toString()));
    }

  }

  //******************************************************************************************************************
  //Start of the app UI build
  //******************************************************************************************************************

  @override
  Widget build(BuildContext context) {

    final emailField = TextField(
      enabled: typeChosen,
      style: style,
      controller: emailController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Email",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final passwordField = TextField(
      obscureText: true,
      enabled: typeChosen,
      style: style,
      controller: passwordController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Password",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    //TO DO: look into using dropdowns for city and state

    final cityField = TextField(
      enabled: typeChosen,
      style: style,
      controller: cityController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "City",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final stateField = TextField(
      enabled: typeChosen,
      style: style,
      controller: stateController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "State",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    //venue-specific fields

    final nameField = TextField(
      enabled: venueChosen,
      style: style,
      controller: vnameController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Venue Name",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final addressField = TextField(
      enabled: venueChosen,
      style: style,
      controller: addressController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Address",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final zipField = TextField(
      enabled: venueChosen,
      style: style,
      controller: zipController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "ZIP Code",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final venuetypeField = TextField(
      enabled: venueChosen,
      style: style,
      controller: vtypeController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Venue Type",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    //fan-specific fields

    final fnameField = TextField(
      enabled: fanChosen,
      style: style,
      controller: fnameController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "First Name",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final lnameField = TextField(
      enabled: fanChosen,
      style: style,
      controller: lnameController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Last Name",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final fandobField = TextField(
      enabled: fanChosen,
      style: style,
      controller: fandobController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Date of Birth (mm/dd/yyyy)",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    //artist-specific fields

    final artistnameField = TextField(
      enabled: artistChosen,
      style: style,
      controller: artistnameController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Artist Name",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final artistgenreField = TextField(
      enabled: artistChosen,
      style: style,
      controller: artistgenreController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Artist Genre",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final RegisterButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          switch(radioValue1){
            case 1: RegisterFan(emailController.text, passwordController.text, fnameController.text, lnameController.text, cityController.text, stateController.text, fandobController.text);
            break;
            case 2: RegisterVenue(emailController.text, passwordController.text, vnameController.text, addressController.text, cityController.text, stateController.text, zipController.text, vtypeController.text);
            break;
            case 3: RegisterArtist(emailController.text, passwordController.text, artistnameController.text, artistgenreController.text, cityController.text, stateController.text);
            break;
          }
        },
        child: Text("Register",
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
                    Padding(padding: EdgeInsets.all(30.0)),
                    new Text(
                      'Who are you?',
                      style: new TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    SizedBox(
                      height: 50.0,
                      child: new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          new Radio(
                            value: 1,
                            groupValue: radioValue1,
                            onChanged: _handleRadioValueChange1,
                          ),
                          new Text(
                            'A fan',
                            style: new TextStyle(fontSize: 16.0),
                          ),
                          new Radio(
                            value: 2,
                            groupValue: radioValue1,
                            onChanged: _handleRadioValueChange1,
                          ),
                          new Text(
                            'a venue',
                            style: new TextStyle(
                              fontSize: 16.0,
                            ),
                          ),
                          new Radio(
                            value: 3,
                            groupValue: radioValue1,
                            onChanged: _handleRadioValueChange1,
                          ),
                          new Text(
                            'an artist',
                            style: new TextStyle(
                              fontSize: 16.0,
                            ),
                          )
                        ],
                      ),
                    ),

                    Visibility(
                        visible: typeChosen,
                        child:
                          Column(
                            children: [
                              SizedBox(height: 45.0),
                              emailField,
                              SizedBox(height: 25.0),
                              passwordField,
                            ]
                          )
                    ),
                    Visibility(
                        visible: venueChosen,
                        child:
                        Column(
                            children: [
                              SizedBox(height: 25.0),
                              nameField,
                              SizedBox(height: 25.0),
                              addressField,
                              SizedBox(height: 25.0),
                              zipField,
                              SizedBox(height: 25.0),
                              venuetypeField,
                            ]
                        )
                    ),
                    Visibility(
                        visible: fanChosen,
                        child:
                        Column(
                            children: [
                              SizedBox(height: 25.0),
                              fnameField,
                              SizedBox(height: 25.0),
                              lnameField,
                              SizedBox(height: 25.0),
                              fandobField,
                            ]
                        )
                    ),
                    Visibility(
                        visible: artistChosen,
                        child:
                        Column(
                            children: [
                              SizedBox(height: 25.0),
                              artistnameField,
                              SizedBox(height: 25.0),
                              artistgenreField,
                            ]
                        )
                    ),
                    Visibility(
                        visible: typeChosen,
                        child:
                            Column(
                              children: [
                                  SizedBox(height: 25.0),
                                  cityField,
                                  SizedBox(height: 25.0),
                                  stateField,
                                  SizedBox(
                                    height: 35.0,
                                  ),
                                  RegisterButon,
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                ])),
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}