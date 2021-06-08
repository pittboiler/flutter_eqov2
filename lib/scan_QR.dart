import 'package:barcode_scan_fix/barcode_scan.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';

class ScanQR extends StatefulWidget {

  static const routeName = '/ScanQRRoute';

  @override
  _ScanQRState createState() => _ScanQRState();
}

class _ScanQRState extends State<ScanQR> {

  String qrCodeResult = "Not Yet Scanned";

  Future<void> TicketConfirmation(qrcodeinput)

  async {

    List<String> input_list = qrcodeinput.split("#");
    String user_id = input_list[0];
    String show_id = input_list[1];

    //temporary hard-coded inputs
    Map<String, String> input_ticket_confirmation = {
      "user_id" : user_id,
      "show_id" : show_id,
      "confirm_attendance" : "yes",
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/attendance_management.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_ticket_confirmation
    );

    var jsonData = json.decode(data.body);

    if(jsonData.contains('Error') == true){
      setState(() {
        qrCodeResult = "The ticket could not be confirmed";
      });
    }
    else{
      setState(() {
        qrCodeResult = "Ticket confirmed";
      });
    }

  }

  //******************************************************************************************************************
  //Start of the app UI build
  //******************************************************************************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan QR Code"),
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //Message displayed over here
            Text(
              "Result",
              style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              qrCodeResult,
              style: TextStyle(
                fontSize: 20.0,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 20.0,
            ),

            //Button to scan QR code
            FlatButton(
              padding: EdgeInsets.all(15),
              onPressed: () async {
                String codeScanner = await BarcodeScanner.scan();    //barcode scnner
                TicketConfirmation(codeScanner);
              },
              child: Text("Open Scanner",style: TextStyle(color: Colors.indigo[900]),),
              //Button having rounded rectangle border
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.indigo[900]),
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),

          ],
        ),
      ),
    );
  }
}