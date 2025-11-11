// CORRECT
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// A class to hold all properties of a text element
class TextElement {
  String text;
  Offset position;
  TextStyle style;
  String fontFamily;
  double fontSize;
  int id; // Unique ID for finding this element

  // A copy of the element for history
  TextElement copy() {
    return TextElement(
      id: id,
      text: text,
      position: position,
      style: style.copyWith(), // Must copy the style
      fontFamily: fontFamily,
      fontSize: fontSize,
    );
  }

  TextElement({
    required this.id,
    this.text = 'Tap to Edit',
    this.position = const Offset(100, 100),
    this.style = const TextStyle(color: Colors.black),
    this.fontFamily = 'Roboto',
    this.fontSize = 20.0,
  });
}

// A class to manage the history for undo/redo
class HistoryState {
  final List<TextElement> elements;
  final int? selectedElementId;

  HistoryState({required this.elements, this.selectedElementId});

  // Create a deep copy of the elements list
  static List<TextElement> deepCopy(List<TextElement> list) {
    return list.map((e) => e.copy()).toList();
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Text Canvas',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
      home: const TextCanvasPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TextCanvasPage extends StatefulWidget {
  const TextCanvasPage({super.key});

  @override
  State<TextCanvasPage> createState() => _TextCanvasPageState();
}

class _TextCanvasPageState extends State<TextCanvasPage> {
  // List of all text elements on the canvas
  List<TextElement> _elements = [];
  int? _selectedElementId;
  int _nextElementId = 0; // Counter for unique IDs

  // For Undo/Redo
  final List<HistoryState> _history = [];
  List<HistoryState> _redoStack = [];

  // --- NEW: State for inline editing ---
  int? _editingElementId;
  TextEditingController? _editingController;
  late FocusNode _textFocusNode; // Declared as late
  // ---

  // Available fonts to choose from
  final List<String> _fontFamilies = [
    'Roboto',
    'Lato',
    'Montserrat',
    'Oswald',
    'Playfair Display',
    'Source Sans 3', // Corrected font name
  ];

  @override
  void initState() {
    super.initState();
    // Save the initial empty state
    _saveState();
    _textFocusNode = FocusNode(); // Initialize focus node
  }

  @override
  void dispose() {
    _editingController?.dispose(); // Dispose controller if it exists
    _textFocusNode.dispose(); // Dispose focus node
    super.dispose();
  }

  // --- History & State Management ---

  void _saveState() {
    // Create a deep copy of the current state
    final currentState = HistoryState(
      elements: HistoryState.deepCopy(_elements),
      selectedElementId: _selectedElementId,
    );
    _history.add(currentState);
    // When we make a new change, the redo stack must be cleared
    _redoStack = [];
    // Limit history size to prevent memory issues (optional)
    if (_history.length > 50) {
      _history.removeAt(0);
    }
    setState(() {}); // Update UI to reflect undo/redo button state
  }

  void _undo() {
    if (_history.length > 1) {
      // Move the current state to the redo stack
      final currentState = _history.removeLast();
      _redoStack.add(currentState);
      // Restore the previous state
      _restoreState(_history.last);
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      // Get the state from the redo stack
      final nextState = _redoStack.removeLast();
      // Add it back to history
      _history.add(nextState);
      // Restore it
      _restoreState(nextState);
    }
  }

  void _restoreState(HistoryState state) {
    setState(() {
      _elements = HistoryState.deepCopy(state.elements);
      _selectedElementId = state.selectedElementId;
    });
  }

  // --- Text Element Actions ---

  // Get the currently selected element, or null
  TextElement? get _selectedElement {
    if (_selectedElementId == null) return null;
    try {
      return _elements.firstWhere((e) => e.id == _selectedElementId);
    } catch (e) {
      return null;
    }
  }

  void _addText() {
    setState(() {
      final newId = _nextElementId++;
      final newElement = TextElement(
        id: newId,
        position: const Offset(100, 100), // Default position
      );
      _elements.add(newElement);
      _selectedElementId = newId; // Select the new text
      _startEditing(newElement); // --- NEW: Start editing immediately
    });
    _saveState(); // Save this action
  }

  // --- NEW: Start and Stop Editing Functions ---

  void _startEditing(TextElement element) {
    // If we're already editing, dispose the old controller
    _editingController?.dispose();

    setState(() {
      _editingElementId = element.id;
      _selectedElementId = element.id; // Ensure it's also selected
      _editingController = TextEditingController(text: element.text);
    });

    // Re-add explicit focus request for Android — forces keyboard to appear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  void _stopEditing() {
    if (_editingElementId == null) return;

    final element = _elements.firstWhere((e) => e.id == _editingElementId);
    final newText = _editingController?.text ?? element.text;

    // Dispose the controller
    _editingController?.dispose();
    _editingController = null;

    setState(() {
      element.text = newText;
      _editingElementId = null; // Exit edit mode
    });
    _saveState(); // Save the text change
  }

  // --- Style Change Actions ---

  void _changeFontFamily(String? newFamily) {
    if (_selectedElement != null && newFamily != null) {
      setState(() {
        _selectedElement!.fontFamily = newFamily;
        _updateSelectedElementStyle(); // Apply the font
      });
      // --- LOGIC FIX: Only save state if NOT editing ---
      if (_editingElementId == null) {
        _saveState();
      }
    }
  }

  void _changeFontSize(double delta) {
    if (_selectedElement != null) {
      setState(() {
        _selectedElement!.fontSize = (_selectedElement!.fontSize + delta).clamp(
          8.0,
          100.0,
        );
        _updateSelectedElementStyle(); // Apply the size
      });
      // --- LOGIC FIX: Only save state if NOT editing ---
      if (_editingElementId == null) {
        _saveState();
      }
    }
  }

  void _toggleBold() {
    if (_selectedElement != null) {
      setState(() {
        final currentWeight = _selectedElement!.style.fontWeight;
        _selectedElement!.style = _selectedElement!.style.copyWith(
          fontWeight: currentWeight == FontWeight.bold
              ? FontWeight.normal
              : FontWeight.bold,
        );
      });
      // --- LOGIC FIX: Only save state if NOT editing ---
      if (_editingElementId == null) {
        _saveState();
      }
    }
  }

  void _toggleItalic() {
    if (_selectedElement != null) {
      setState(() {
        final currentStyle = _selectedElement!.style.fontStyle;
        _selectedElement!.style = _selectedElement!.style.copyWith(
          fontStyle: currentStyle == FontStyle.italic
              ? FontStyle.normal
              : FontStyle.italic,
        );
      });
      // --- LOGIC FIX: Only save state if NOT editing ---
      if (_editingElementId == null) {
        _saveState();
      }
    }
  }

  void _toggleUnderline() {
    if (_selectedElement != null) {
      setState(() {
        final currentDecoration = _selectedElement!.style.decoration;
        _selectedElement!.style = _selectedElement!.style.copyWith(
          decoration: currentDecoration == TextDecoration.underline
              ? TextDecoration.none
              : TextDecoration.underline,
        );
      });
      // --- LOGIC FIX: Only save state if NOT editing ---
      if (_editingElementId == null) {
        _saveState();
      }
    }
  }

  // Helper to apply Google Font
  void _updateSelectedElementStyle() {
    if (_selectedElement == null) return;
    final element = _selectedElement!;
    element.style = GoogleFonts.getFont(
      element.fontFamily,
      textStyle: element.style.copyWith(fontSize: element.fontSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Centered Undo/Redo buttons
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Undo Button
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _history.length > 1
                  ? _undo
                  : null, // Disable if nothing to undo
              tooltip: 'Undo',
            ),
            // Redo Button
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty
                  ? _redo
                  : null, // Disable if nothing to redo
              tooltip: 'Redo',
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      // --- UI CHANGE: REMOVED floatingActionButton ---
      // floatingActionButton: FloatingActionButton.extended(...)
      body: Stack(
        // --- UI CHANGE: Added Stack ---
        children: [
          Column(
            children: [
              // --- The Canvas ---
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // If we're currently editing an element, ignore taps on the
                    // canvas background so the TextField can handle them on
                    // Android (prevents the background from immediately
                    // cancelling edit mode). Otherwise, unselect and stop
                    // editing as before.
                    if (_editingElementId != null) return;
                    // Unselect and stop editing when tapping the canvas background
                    _stopEditing(); // Commit any changes
                    setState(() {
                      _selectedElementId = null;
                    });
                    _saveState();
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200], // Canvas background
                    child: Stack(
                      children: _elements.map((element) {
                        return Positioned(
                          left: element.position.dx,
                          top: element.position.dy,
                          child: _buildDraggableText(element),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              // --- The Toolbar ---
              // --- UI FIX: Wrap toolbar in a SafeArea to avoid system navigation ---
              SafeArea(
                top: false, // We only care about the bottom edge
                child: _buildToolbar(),
              ),
            ],
          ),

          // --- UI CHANGE: Added Positioned Button ---
          Positioned(
            left: 0,
            right: 0,
            bottom:
                72.0, // Lifts button 72px from bottom (64px toolbar + 8px space)
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: _addText,
                tooltip: 'Add Text',
                icon: const Icon(Icons.add),
                label: const Text('Add Text'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Builders ---

  // Builds the draggable text widget
  Widget _buildDraggableText(TextElement element) {
    final bool isSelected = element.id == _selectedElementId;
    final bool isEditing = element.id == _editingElementId;

    // Set cursor based on state
    final MouseCursor cursor;
    if (isEditing || isSelected) {
      cursor = SystemMouseCursors.text; // Text I-beam cursor
    } else {
      cursor = SystemMouseCursors.grab; // "Hand" cursor when not selected
    }

    Widget child;
    if (isEditing) {
      // EDITING WIDGET (TextField)
      child = IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            // Show a border *while* editing
            border: Border.all(
              color: Colors.blue,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: TextField(
            controller: _editingController,
            focusNode: _textFocusNode,
            // Request autofocus so the IME reliably opens on Android.
            // We still call requestFocus in _startEditing; this is an
            // additional, low-risk aid for platform focus quirks.
            autofocus: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            enableInteractiveSelection: true,
            showCursor: true,
            // Keep UI responsive during typing so the typed characters
            // appear immediately while editing. We do not commit until
            // _stopEditing is called, so undo/redo logic remains unchanged.
            onChanged: (value) {
              setState(() {});
            },
            // Use a collapsed input decoration (no visible border) instead of null
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: GoogleFonts.getFont(
              element.fontFamily,
              textStyle: element.style.copyWith(fontSize: element.fontSize),
            ),
            onSubmitted: (value) {
              // onSubmitted fires with an IME action; keep behavior (commit on enter)
              _stopEditing();
            },
            minLines: 1,
            maxLines: null, // Allow multiline
          ),
        ),
      );
    } else {
      // DISPLAY WIDGET (Text)
      child = GestureDetector(
        onTap: () {
          if (isSelected) {
            // If already selected, tap means "start editing"
            _startEditing(element);
          } else {
            // If not selected, tap means "select"
            _stopEditing();
            setState(() {
              _selectedElementId = element.id;
            });
            _saveState(); // Save selection change
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(
                    color: Colors.blue,
                    width: 2,
                    style: BorderStyle.solid,
                  )
                : null,
          ),
          child: Text(
            element.text.isEmpty ? 'Tap to Edit' : element.text,
            style: GoogleFonts.getFont(
              element.fontFamily,
              textStyle: element.style.copyWith(fontSize: element.fontSize),
            ),
          ),
        ),
      );
    }

    if (isEditing) {
      // while editing, absorb taps so background doesn't immediately stop editing
      return MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          // Let the child (TextField) handle touch events first so the
          // TextField can receive taps/cursor placement and open the
          // keyboard on Android. Using deferToChild avoids swallowing
          // gestures that the TextField needs while still preventing
          // the background canvas from receiving taps when the child is hit.
          behavior: HitTestBehavior.deferToChild,
          onTap: () {
            // Ensure taps on the editing area give focus to the TextField on
            // Android. This explicitly requests focus so the IME opens and
            // the cursor appears where the user tapped.
            FocusScope.of(context).requestFocus(_textFocusNode);
          },
          child: child,
        ),
      );
    }

    // Normal draggable (not editing)
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (isEditing) return; // Don't drag while editing
          setState(() {
            element.position += details.delta;
          });
        },
        onPanEnd: (details) {
          _saveState();
        },
        child: child,
      ),
    );
  }

  // Builds the bottom toolbar
  Widget _buildToolbar() {
    final bool isElementSelected = _selectedElement != null;
    final selectedFontFamily =
        _selectedElement?.fontFamily ?? _fontFamilies.first;
    final selectedFontSize = _selectedElement?.fontSize ?? 20.0;
    final isBold = _selectedElement?.style.fontWeight == FontWeight.bold;
    final isItalic = _selectedElement?.style.fontStyle == FontStyle.italic;
    final isUnderline =
        _selectedElement?.style.decoration == TextDecoration.underline;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.1), // Fixed deprecation
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // --- Font Family Dropdown ---
          Flexible(
            child: DropdownButton<String>(
              value: selectedFontFamily,
              hint: const Text('Font'),
              isExpanded:
                  true, // --- NEW UI FIX: Tell dropdown to use flexible space
              onChanged: isElementSelected ? _changeFontFamily : null,
              items: _fontFamilies.map((String family) {
                return DropdownMenuItem<String>(
                  value: family,
                  child: Text(
                    family,
                    style: GoogleFonts.getFont(family),
                    // Add overflow handling for long font names
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),

          // --- OVERFLOW FIX: Group Font Size Controls ---
          // --- NEW UI FIX: Wrap in FittedBox to shrink ---
          FittedBox(
            child: Row(
              mainAxisSize:
                  MainAxisSize.min, // Prevents this Row from expanding
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: isElementSelected
                      ? () => _changeFontSize(-2)
                      : null,
                ),
                Text(selectedFontSize.toStringAsFixed(0)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: isElementSelected
                      ? () => _changeFontSize(2)
                      : null,
                ),
              ],
            ),
          ),
          // --- END OF FIX ---

          // --- Font Style Toggles ---
          // --- NEW UI FIX: Wrap in FittedBox to shrink ---
          FittedBox(
            child: ToggleButtons(
              isSelected: [isBold, isItalic, isUnderline],
              onPressed: isElementSelected
                  ? (index) {
                      if (index == 0) _toggleBold();
                      if (index == 1) _toggleItalic();
                      if (index == 2) _toggleUnderline();
                    }
                  : null,
              children: const [
                Icon(Icons.format_bold),
                Icon(Icons.format_italic),
                Icon(Icons.format_underline),
              ],
            ),
          ),
          // --- END OF FIX ---
        ],
      ),
    );
  }
}
