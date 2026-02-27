import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class TrackOrderPage extends StatefulWidget {
  const TrackOrderPage({super.key});

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  late GoogleMapController mapController;
  late socket_io.Socket socket;

  LatLng deliveryBoy = const LatLng(15.6235, 76.9048);
  final LatLng customer = const LatLng(15.6225, 76.9040);

  final String orderId = "69510eb308e73e5017692e0c";

  @override
  void initState() {
    super.initState();

    socket = socket_io.io("http://localhost:5000", {
      "transports": ["websocket"],
      "autoConnect": true,
    });

    socket.onConnect((_) {
      socket.emit("joinOrderRoom", orderId);
    });

    socket.on("locationBroadcast", (data) {
      setState(() {
        deliveryBoy = LatLng(data["lat"], data["lng"]);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Order Tracking")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: deliveryBoy,
          zoom: 15,
        ),
        markers: {
          Marker(markerId: const MarkerId("delivery"), position: deliveryBoy),
          Marker(markerId: const MarkerId("customer"), position: customer),
        },
        onMapCreated: (controller) {
          mapController = controller;
        },
      ),
    );
  }
}
