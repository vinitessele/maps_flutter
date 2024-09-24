import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<LatLng> _routePoints = [];
  LatLng? _startPoint;
  LatLng? _endPoint;

  // Coordenada inicial para o mapa centralizado no Brasil
  static const LatLng _initialLatLng = LatLng(-14.2350, -51.9253);
  static const double _initialZoom = 4.0; // Nível de zoom inicial

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Para iniciar com a localização atual
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviço de localização está desabilitado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissão de localização foi negada.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissão de localização foi negada permanentemente.');
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _startPoint = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _getRoute() async {
    if (_startPoint == null || _endPoint == null) {
      return;
    }

    final apiKey = '5b3ce3597851110001cf6248f55d7a31499e40848c6848d7de8fa624';
    final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${_startPoint!.longitude},${_startPoint!.latitude}&end=${_endPoint!.longitude},${_endPoint!.latitude}';
    
    print(url);
    final response = await http.get(Uri.parse(url));
    print(response);

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['routes'].isNotEmpty) {
        final route = jsonResponse['routes'][0]['geometry']['coordinates'];
        final duration = jsonResponse['routes'][0]['summary']['duration']; // Tempo em segundos
        final distance = jsonResponse['routes'][0]['summary']['distance']; // Distância em metros

        setState(() {
          _routePoints.clear();
          for (var point in route) {
            _routePoints.add(LatLng(point[1], point[0]));
          }
        });

        // Exibir a descrição da rota
        _showRouteDescription(duration, distance);
      } else {
        _showErrorDialog('Nenhuma rota encontrada.');
      }
    } else {
      _showErrorDialog('Erro ao buscar a rota: ${response.statusCode}');
      print(response.body); // Para debug
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _onMapTap(LatLng point) {
    setState(() {
      if (_startPoint == null) {
        _startPoint = point;
      } else if (_endPoint == null) {
        _endPoint = point;
        _getRoute(); // Traçar a rota
      } else {
        // Limpar os pontos e a rota se ambos já foram definidos
        _startPoint = point;
        _endPoint = null;
        _routePoints.clear();
      }
    });
  }

  void _showRouteDescription(int duration, int distance) {
    final durationInMinutes = (duration / 60).toStringAsFixed(0); // Convertendo para minutos
    final distanceInKm = (distance / 1000).toStringAsFixed(1); // Convertendo para quilômetros

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Descrição da Rota'),
          content: Text('Distância: $distanceInKm km\nTempo estimado: $durationInMinutes min'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traçar Rota no Mapa'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _initialLatLng, // Define o centro inicial do mapa
                initialZoom: _initialZoom, // Define o nível de zoom inicial
                onTap: (tapPosition, point) {
                  _onMapTap(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                if (_startPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _startPoint!,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                if (_endPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _endPoint!,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.grey,
                        strokeWidth: 15.0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _startPoint == null
                  ? 'Clique para definir o ponto inicial...'
                  : _endPoint == null
                      ? 'Clique para definir o ponto final'
                      : 'Rota traçada com sucesso!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          if (_startPoint != null && _endPoint != null)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _startPoint = null;
                  _endPoint = null;
                  _routePoints.clear();
                });
              },
              child: const Text('Limpar Rota'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
