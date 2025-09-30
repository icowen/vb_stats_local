import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../services/event_service.dart';

enum UndoActionType { create, delete, update }

class UndoAction {
  final UndoActionType type;
  final Event? originalEvent;
  final Event? updatedEvent;
  final String description;

  UndoAction({
    required this.type,
    this.originalEvent,
    this.updatedEvent,
    required this.description,
  });
}

class EventProvider extends ChangeNotifier {
  final EventService _eventService = EventService();

  // Undo/Redo system
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];

  static const int maxUndoActions = 20;

  // Getters
  List<UndoAction> get undoStack => List.unmodifiable(_undoStack);
  List<UndoAction> get redoStack => List.unmodifiable(_redoStack);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Add event with undo tracking
  Future<void> addEvent(Event event, {String? description}) async {
    try {
      await _eventService.insertEvent(event);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.create,
          originalEvent: event,
          description: description ?? 'Add ${event.type.name} event',
        ),
      );

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to add event: $e');
    }
  }

  // Update event with undo tracking
  Future<void> updateEvent(
    Event originalEvent,
    Event updatedEvent, {
    String? description,
  }) async {
    try {
      await _eventService.updateEvent(updatedEvent);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.update,
          originalEvent: originalEvent,
          updatedEvent: updatedEvent,
          description: description ?? 'Update ${updatedEvent.type.name} event',
        ),
      );

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete event with undo tracking
  Future<void> deleteEvent(Event event, {String? description}) async {
    try {
      await _eventService.deleteEvent(event.id!);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.delete,
          originalEvent: event,
          description: description ?? 'Delete ${event.type.name} event',
        ),
      );

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  // Undo last action
  Future<UndoAction?> undoLastAction() async {
    if (_undoStack.isEmpty) return null;

    final action = _undoStack.removeLast();

    try {
      switch (action.type) {
        case UndoActionType.create:
          // Undo creation by deleting the event
          if (action.originalEvent != null) {
            await _eventService.deleteEvent(action.originalEvent!.id!);
          }
          break;

        case UndoActionType.delete:
          // Undo deletion by recreating the event
          if (action.originalEvent != null) {
            await _eventService.insertEvent(action.originalEvent!);
          }
          break;

        case UndoActionType.update:
          // Undo update by restoring original event
          if (action.originalEvent != null) {
            await _eventService.updateEvent(action.originalEvent!);
          }
          break;
      }

      // Add to redo stack
      _redoStack.add(action);

      // Limit redo stack size
      if (_redoStack.length > maxUndoActions) {
        _redoStack.removeAt(0);
      }

      notifyListeners();
      return action;
    } catch (e) {
      // If undo fails, put the action back
      _undoStack.add(action);
      throw Exception('Failed to undo action: $e');
    }
  }

  // Redo last action
  Future<UndoAction?> redoLastAction() async {
    if (_redoStack.isEmpty) return null;

    final action = _redoStack.removeLast();

    try {
      switch (action.type) {
        case UndoActionType.create:
          // Redo creation by recreating the event
          if (action.originalEvent != null) {
            await _eventService.insertEvent(action.originalEvent!);
          }
          break;

        case UndoActionType.delete:
          // Redo deletion by deleting the event
          if (action.originalEvent != null) {
            await _eventService.deleteEvent(action.originalEvent!.id!);
          }
          break;

        case UndoActionType.update:
          // Redo update by applying the updated event
          if (action.updatedEvent != null) {
            await _eventService.updateEvent(action.updatedEvent!);
          }
          break;
      }

      // Add back to undo stack
      _undoStack.add(action);

      // Limit undo stack size
      if (_undoStack.length > maxUndoActions) {
        _undoStack.removeAt(0);
      }

      notifyListeners();
      return action;
    } catch (e) {
      // If redo fails, put the action back
      _redoStack.add(action);
      throw Exception('Failed to redo action: $e');
    }
  }

  // Clear undo/redo stacks
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  // Private helper methods
  void _addUndoAction(UndoAction action) {
    _undoStack.add(action);

    // Clear redo stack when new action is added
    _redoStack.clear();

    // Limit undo stack size
    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }
}
