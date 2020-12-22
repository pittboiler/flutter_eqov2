import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';

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

  //if adding artists, will need to add fields, controllers, radio buttons, and a separate function

  //form handling controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fnameController = TextEditingController();
  final lnameController = TextEditingController();
  final vnameController = TextEditingController();
  final addressController = TextEditingController();
  final zipController = TextEditingController();
  final vtypeController = TextEditingController();

  //radio button and field display handling
  int radioValue1 = -1;
  bool typeChosen = false;
  bool fanChosen = false;
  bool venueChosen = false;

  void _handleRadioValueChange1(int value) {
    setState(() {
      radioValue1 = value;
      typeChosen = true;
      if(radioValue1 == 1){
        fanChosen = true;
        venueChosen = false;
      }
      else {
        venueChosen = true;
        fanChosen = false;
      }
    });
  }

  //core register functions

  //fan register: take inputs from login field, run by code validation, output login info or error message
  Future<List<FanRegister>> RegisterFan(input_email, input_password, input_fname, input_lname)

  async {

    Map<String, String> input_data_register_fan = {
      "switch_fan" : "yes",
      "email": input_email,
      "password" : input_password,
      "first_name" : input_fname,
      "last_name" : input_lname,
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
          arguments: FanRegister(jsonData[0].toString(), jsonData[1].toString()));
    }

  }

  //venue register: take inputs from login field, run by code validation, output login info or error message
  Future<List<VenueRegister>> RegisterVenue(input_email, input_password, input_vname, input_address, input_zip, input_vtype)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_data_register_venue = {
      "switch_venue" : "yes",
      "email": input_email,
      "password" : input_password,
      "venue_name" : input_vname,
      "address" : input_address,
      "address_zip_code" : input_zip,
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
          arguments: VenueRegister(jsonData[0].toString(), jsonData[1].toString()));
    }

  }

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
      enabled: typeChosen,
      style: style,
      controller: passwordController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Password",
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


    final RegisterButton = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          switch(radioValue1){
            case 1: RegisterFan(emailController.text, passwordController.text, fnameController.text, lnameController.text);
            break;
            case 2: RegisterVenue(emailController.text, passwordController.text, vnameController.text, addressController.text, zipController.text, vtypeController.text);
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
                            ]
                        )
                    ),
                    SizedBox(
                      height: 35.0,
                    ),
                    RegisterButton,
                    SizedBox(
                      height: 15.0,
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

class FanRegister {
  final String user_id;
  final String user_type;

  FanRegister(this.user_id, this.user_type);

}

class VenueRegister {
  final String user_id;
  final String user_type;

  VenueRegister(this.user_id, this.user_type);

}

class UserData {
  final String user_id;
  final String user_type;

  UserData(this.user_id, this.user_type);

}