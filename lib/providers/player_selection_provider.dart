import 'package:flutter/foundation.dart';
import '../models/player.dart';

class PlayerSelectionProvider extends ChangeNotifier {
  // Player selection state
  Player? _selectedPlayer;

  // Court coordinate tracking
  bool _isRecordingCoordinates = false;
  String? _recordingAction;
  double? _startX;
  double? _startY;
  double? _endX;
  double? _endY;
  bool _hasStartPoint = false;

  // Display coordinates (original, not normalized)
  double? _displayStartX;
  double? _displayStartY;
  double? _displayEndX;
  double? _displayEndY;

  // Action selection for iterative stats
  String? _selectedActionType; // 'serve', 'pass', 'attack'
  String? _selectedServeResult; // 'ace', 'in', 'error'
  String? _selectedPassRating; // 'ace', '3', '2', '1', '0'
  String? _selectedAttackResult; // 'kill', 'in', 'error'
  String? _selectedServeType;

  // Attack metadata selection (multiple selection)
  final Set<String> _selectedAttackMetadata = {};

  // Pass type selection (single selection)
  String? _selectedPassType;

  // Freeball action selection
  String? _selectedFreeballAction; // 'sent' or 'received'
  String? _selectedFreeballResult; // 'good' or 'bad' (for received only)

  // Blocking action selection
  String? _selectedBlockingType; // 'solo', 'assist', or 'error'

  // Dig action selection
  String? _selectedDigType; // 'overhand' or 'platform'

  // Set action selection
  String? _selectedSetType; // 'in_system' or 'out_of_system'

  // Court zones - 6 zones per side (2 columns × 3 rows)
  Map<String, int?> _courtZones = {
    // Home side - 6 zones
    'home_1': null, 'home_2': null, 'home_3': null,
    'home_4': null, 'home_5': null, 'home_6': null,
    // Away side - 6 zones
    'away_1': null, 'away_2': null, 'away_3': null,
    'away_4': null, 'away_5': null, 'away_6': null,
  };

  // Getters
  Player? get selectedPlayer => _selectedPlayer;
  bool get isRecordingCoordinates => _isRecordingCoordinates;
  String? get recordingAction => _recordingAction;
  double? get startX => _startX;
  double? get startY => _startY;
  double? get endX => _endX;
  double? get endY => _endY;
  bool get hasStartPoint => _hasStartPoint;
  double? get displayStartX => _displayStartX;
  double? get displayStartY => _displayStartY;
  double? get displayEndX => _displayEndX;
  double? get displayEndY => _displayEndY;
  String? get selectedActionType => _selectedActionType;
  String? get selectedServeResult => _selectedServeResult;
  String? get selectedPassRating => _selectedPassRating;
  String? get selectedAttackResult => _selectedAttackResult;
  String? get selectedServeType => _selectedServeType;
  Set<String> get selectedAttackMetadata => _selectedAttackMetadata;
  String? get selectedPassType => _selectedPassType;
  String? get selectedFreeballAction => _selectedFreeballAction;
  String? get selectedFreeballResult => _selectedFreeballResult;
  String? get selectedBlockingType => _selectedBlockingType;
  String? get selectedDigType => _selectedDigType;
  String? get selectedSetType => _selectedSetType;
  Map<String, int?> get courtZones => _courtZones;

  // Player selection methods
  void selectPlayer(Player? player) {
    _selectedPlayer = player;
    notifyListeners();
  }

  void clearPlayerSelection() {
    _selectedPlayer = null;
    notifyListeners();
  }

  // Coordinate recording methods
  void startCoordinateRecording(String action) {
    _isRecordingCoordinates = true;
    _recordingAction = action;
    notifyListeners();
  }

  void stopCoordinateRecording() {
    _isRecordingCoordinates = false;
    _recordingAction = null;
    notifyListeners();
  }

  void setStartPoint(double x, double y) {
    _startX = x;
    _startY = y;
    _hasStartPoint = true;
    _displayStartX = x * 60.0; // Convert to feet
    _displayStartY = y * 30.0; // Convert to feet
    notifyListeners();
  }

  void setEndPoint(double x, double y) {
    _endX = x;
    _endY = y;
    _displayEndX = x * 60.0; // Convert to feet
    _displayEndY = y * 30.0; // Convert to feet
    notifyListeners();
  }

  void clearCoordinates() {
    _startX = null;
    _startY = null;
    _endX = null;
    _endY = null;
    _hasStartPoint = false;
    _displayStartX = null;
    _displayStartY = null;
    _displayEndX = null;
    _displayEndY = null;
    notifyListeners();
  }

  // Action selection methods
  void selectActionType(String? actionType) {
    _selectedActionType = actionType;
    notifyListeners();
  }

  void selectServeResult(String? result) {
    _selectedServeResult = result;
    notifyListeners();
  }

  void selectPassRating(String? rating) {
    _selectedPassRating = rating;
    notifyListeners();
  }

  void selectAttackResult(String? result) {
    _selectedAttackResult = result;
    notifyListeners();
  }

  void selectServeType(String? serveType) {
    _selectedServeType = serveType;
    notifyListeners();
  }

  void toggleAttackMetadata(String metadata) {
    if (_selectedAttackMetadata.contains(metadata)) {
      _selectedAttackMetadata.remove(metadata);
    } else {
      _selectedAttackMetadata.add(metadata);
    }
    notifyListeners();
  }

  void clearAttackMetadata() {
    _selectedAttackMetadata.clear();
    notifyListeners();
  }

  void selectPassType(String? passType) {
    _selectedPassType = passType;
    notifyListeners();
  }

  void selectFreeballAction(String? action) {
    _selectedFreeballAction = action;
    notifyListeners();
  }

  void selectFreeballResult(String? result) {
    _selectedFreeballResult = result;
    notifyListeners();
  }

  void selectBlockingType(String? blockingType) {
    _selectedBlockingType = blockingType;
    notifyListeners();
  }

  void selectDigType(String? digType) {
    _selectedDigType = digType;
    notifyListeners();
  }

  void selectSetType(String? setType) {
    _selectedSetType = setType;
    notifyListeners();
  }

  // Clear all action selections
  void clearAllActionSelections() {
    _selectedActionType = null;
    _selectedServeResult = null;
    _selectedPassRating = null;
    _selectedAttackResult = null;
    _selectedServeType = null;
    _selectedAttackMetadata.clear();
    _selectedPassType = null;
    _selectedFreeballAction = null;
    _selectedFreeballResult = null;
    _selectedBlockingType = null;
    _selectedDigType = null;
    _selectedSetType = null;
    notifyListeners();
  }

  // Court zone methods
  void assignPlayerToZone(Player player, String zoneKey) {
    // Create a new map to ensure proper repainting
    _courtZones = Map<String, int?>.from(_courtZones);

    // Remove player from any other zone first
    for (String key in _courtZones.keys) {
      if (_courtZones[key] == player.id) {
        _courtZones[key] = null;
      }
    }
    // Assign player to selected zone
    _courtZones[zoneKey] = player.id;
    // Clear player selection
    _selectedPlayer = null;

    notifyListeners();
  }

  void clearZone(String zoneKey) {
    // Create a new map to ensure proper repainting
    _courtZones = Map<String, int?>.from(_courtZones);
    _courtZones[zoneKey] = null;
    notifyListeners();
  }

  bool isPlayerOnCourt(int playerId) {
    return _courtZones.values.contains(playerId);
  }

  bool hasAnyPlayersOnCourt() {
    return _courtZones.values.any((playerId) => playerId != null);
  }

  // Helper methods
  void resetAllSelections() {
    _selectedPlayer = null;
    _selectedActionType = null;
    _selectedServeResult = null;
    _selectedPassRating = null;
    _selectedAttackResult = null;
    _selectedServeType = null;
    _selectedAttackMetadata.clear();
    _selectedPassType = null;
    _selectedFreeballAction = null;
    _selectedFreeballResult = null;
    _selectedBlockingType = null;
    _selectedDigType = null;
    _selectedSetType = null;
    clearCoordinates();
    notifyListeners();
  }
}
