import 'package:flutter/material.dart';
import 'dart:math' as math;

class CoordinateInputWidget extends StatefulWidget {
  final Function(double, double, double) onCoordinatesSubmitted;

  const CoordinateInputWidget({
    Key? key,
    required this.onCoordinatesSubmitted,
  }) : super(key: key);

  @override
  _CoordinateInputWidgetState createState() => _CoordinateInputWidgetState();
}

class _CoordinateInputWidgetState extends State<CoordinateInputWidget> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _angleController = TextEditingController(text: "0");
  final _formKey = GlobalKey<FormState>();
  double _currentAngle = 0.0;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _angleController.dispose();
    super.dispose();
  }

  void _submitCoordinates() {
    if (_formKey.currentState!.validate()) {
      try {
        final double lat = double.parse(_latController.text);
        final double lng = double.parse(_lngController.text);
        final double angle = double.parse(_angleController.text) * (math.pi / 180.0); // Convert to radians
        
        widget.onCoordinatesSubmitted(lat, lng, angle);
        
        // Clear text fields after submission
        _latController.clear();
        _lngController.clear();
        _angleController.text = "0"; // Reset angle to default
        _currentAngle = 0.0;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid values'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,  // Increased to accommodate angle control
      minChildSize: 0.1,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 7,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Draggable indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.only(bottom: 20),
                      ),
                    ),
                    
                    const Text(
                      'Add Car Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Car preview with current angle
                    Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(color: Colors.blue, width: 1)
                        ),
                        child: Transform.rotate(
                          angle: _currentAngle,
                          child: Image.asset(
                            'assets/car.png',
                            width: 40,
                            height: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Latitude TextField
                    TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'Enter latitude (e.g. 31.9539)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter latitude';
                        }
                        try {
                          final lat = double.parse(value);
                          if (lat < -90 || lat > 90) {
                            return 'Latitude must be between -90 and 90';
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Longitude TextField
                    TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'Enter longitude (e.g. 35.9106)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter longitude';
                        }
                        try {
                          final lng = double.parse(value);
                          if (lng < -180 || lng > 180) {
                            return 'Longitude must be between -180 and 180';
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Angle control section
                    const Text(
                      'Car Direction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Angle slider
                    Row(
                      children: [
                        const Icon(Icons.rotate_left, size: 20),
                        Expanded(
                          child: Slider(
                            value: _currentAngle / (2 * math.pi) * 360,
                            min: 0,
                            max: 359,
                            divisions: 36,
                            label: '${(_currentAngle / (math.pi) * 180).round()}°',
                            onChanged: (double value) {
                              setState(() {
                                _currentAngle = value * (math.pi / 180);
                                _angleController.text = value.round().toString();
                              });
                            },
                          ),
                        ),
                        const Icon(Icons.rotate_right, size: 20),
                      ],
                    ),
                    
                    // Angle text field
                    TextFormField(
                      controller: _angleController,
                      decoration: const InputDecoration(
                        labelText: 'Angle (degrees)',
                        hintText: 'Enter angle in degrees (0-359)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.rotate_right),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an angle';
                        }
                        try {
                          final angle = int.parse(value);
                          if (angle < 0 || angle > 359) {
                            return 'Angle must be between 0 and 359';
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        try {
                          final angleValue = double.parse(value);
                          if (angleValue >= 0 && angleValue <= 359) {
                            setState(() {
                              _currentAngle = angleValue * (math.pi / 180);
                            });
                          }
                        } catch (_) {}
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitCoordinates,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Add Car Marker',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}