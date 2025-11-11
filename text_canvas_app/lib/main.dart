import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextElement {
  String text;
  Offset position;
  TextStyle style;
  String fontFamily;
  double fontSize;
  int id;

  TextElement copy() {
    return TextElement(
      id: id,
      text: text,
      position: position,
      style: style.copyWith(),
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

class HistoryState {
  final List<TextElement> elements;
  final int? selectedElementId;

  HistoryState({required this.elements, this.selectedElementId});

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
  List<TextElement> _elements = [];
  int? _selectedElementId;
  int _nextElementId = 0;

  final List<HistoryState> _history = [];
  List<HistoryState> _redoStack = [];

  int? _editingElementId;
  TextEditingController? _editingController;
  late FocusNode _textFocusNode;
  bool _suppressOnChange = false;

  final List<String> _fontFamilies = [
    'Roboto',
    'Lato',
    'Montserrat',
    'Oswald',
    'Playfair Display',
    'Source Sans 3',
  ];

  @override
  void initState() {
    super.initState();

    _saveState();
    _textFocusNode = FocusNode();
  }

  final GlobalKey _canvasKey = GlobalKey();

  @override
  void dispose() {
    _editingController?.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _saveState() {
    final currentState = HistoryState(
      elements: HistoryState.deepCopy(_elements),
      selectedElementId: _selectedElementId,
    );
    if (_editingElementId != null) {
      _history.add(currentState);
      _redoStack = [];
    } else {
      if (_history.isNotEmpty) {
        if (_areStatesEqual(_history.last, currentState)) {
          setState(() {});
          return;
        }
      }
      _history.add(currentState);
      // When we make a new change, the redo stack must be cleared
      _redoStack = [];
    }
    // Limit history size to prevent memory issues (optional)
    if (_history.length > 50) {
      _history.removeAt(0);
    }
    setState(() {}); // Update UI to reflect undo/redo button state
  }

  // Compare two HistoryState objects for meaningful equality
  bool _areStatesEqual(HistoryState a, HistoryState b) {
    if (a.selectedElementId != b.selectedElementId) return false;
    if (a.elements.length != b.elements.length) return false;
    for (int i = 0; i < a.elements.length; i++) {
      final e1 = a.elements[i];
      final e2 = b.elements[i];
      if (e1.id != e2.id) return false;
      if (e1.text != e2.text) return false;
      if (e1.position.dx != e2.position.dx ||
          e1.position.dy != e2.position.dy) {
        return false;
      }
      if (e1.fontFamily != e2.fontFamily) return false;
      if (e1.fontSize != e2.fontSize) return false;
      // Compare a few style attributes
      if (e1.style.fontWeight != e2.style.fontWeight) return false;
      if (e1.style.fontStyle != e2.style.fontStyle) return false;
      if (e1.style.decoration != e2.style.decoration) return false;
    }
    return true;
  }

  // Forcefully save a state ignoring duplicate checks. Use this for
  // explicit user actions that should always be recorded (like style
  // toggles) so undo/redo steps through each user intent.
  void _forceSaveState() {
    final currentState = HistoryState(
      elements: HistoryState.deepCopy(_elements),
      selectedElementId: _selectedElementId,
    );
    _history.add(currentState);
    _redoStack = [];
    if (_history.length > 50) {
      _history.removeAt(0);
    }
    setState(() {});
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
      // If we are currently editing an element, keep the TextField in sync
      // with the restored model so undo/redo updates the visible text
      // while editing instead of leaving the old controller text.
      if (_editingElementId != null && _editingController != null) {
        try {
          final el = _elements.firstWhere((e) => e.id == _editingElementId);
          // Prevent the controller's onChanged from firing a save while we
          // are applying the restored state.
          _suppressOnChange = true;
          _editingController!.text = el.text;
          _editingController!.selection = TextSelection.collapsed(
            offset: _editingController!.text.length,
          );
          _suppressOnChange = false;
        } catch (e) {
          // Element no longer exists; ignore
          _suppressOnChange = false;
        }
      }
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
      // Record this change as a distinct user action so undo/redo
      // steps through font changes even while editing.
      _forceSaveState();
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
      // Record size change as a distinct action so undo/redo steps this
      // change even while editing.
      _forceSaveState();
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
      // Always record toggles as distinct actions so undo reverts them
      // one-by-one, including while editing.
      _forceSaveState();
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
      // Always record toggles so undo/redo steps these while editing.
      _forceSaveState();
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
      // Always record toggles so undo/redo steps these while editing.
      _forceSaveState();
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
                  // Use onTapUp so we can inspect the tap position and only
                  // cancel editing if the tap is outside the editing element's
                  // bounds. This allows taps inside the TextField to be handled
                  // by the TextField (so caret placement and IME work), while
                  // still permitting the user to tap the canvas to finish
                  // editing and then drag the element.
                  onTapUp: (details) {
                    // If nothing is being edited just clear selection as before
                    if (_editingElementId == null) {
                      _stopEditing(); // Commit any changes
                      setState(() {
                        _selectedElementId = null;
                      });
                      _saveState();
                      return;
                    }

                    // We are editing: determine if the tap was inside the
                    // currently editing element. If it was, let the TextField
                    // handle it. If not, stop editing.
                    final canvasBox =
                        _canvasKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (canvasBox == null) return;
                    final localPoint = canvasBox.globalToLocal(
                      details.globalPosition,
                    );

                    TextElement? editingElement;
                    try {
                      editingElement = _elements.firstWhere(
                        (e) => e.id == _editingElementId,
                      );
                    } catch (e) {
                      return;
                    }

                    // Measure the displayed text size using TextPainter so we
                    // can compute a hit rect for the element.
                    final text = editingElement.text.isEmpty
                        ? 'Tap to Edit'
                        : editingElement.text;
                    final tp = TextPainter(
                      text: TextSpan(
                        text: text,
                        style: editingElement.style.copyWith(
                          fontSize: editingElement.fontSize,
                        ),
                      ),
                      textDirection: TextDirection.ltr,
                    )..layout();
                    const padding = 16.0; // small hit padding around text
                    final rect = Rect.fromLTWH(
                      editingElement.position.dx - padding,
                      editingElement.position.dy - padding,
                      tp.width + padding * 2,
                      tp.height + padding * 2,
                    );

                    if (rect.contains(localPoint)) {
                      // Tap was inside the editing element — do nothing and
                      // allow the TextField to handle it.
                      return;
                    }

                    // Tap was outside — finish editing and clear selection.
                    _stopEditing(); // Commit any changes
                    setState(() {
                      _selectedElementId = null;
                    });
                    _saveState();
                  },
                  child: Container(
                    key: _canvasKey,
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
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
              SafeArea(top: false, child: _buildToolbar()),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 72.0,
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

  Widget _buildDraggableText(TextElement element) {
    final bool isSelected = element.id == _selectedElementId;
    final bool isEditing = element.id == _editingElementId;

    final MouseCursor cursor;
    if (isEditing || isSelected) {
      cursor = SystemMouseCursors.text;
    } else {
      cursor = SystemMouseCursors.grab;
    }

    Widget child;
    if (isEditing) {
      child = IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: TextField(
            controller: _editingController,
            focusNode: _textFocusNode,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            enableInteractiveSelection: true,
            showCursor: true,
            onChanged: (value) {
              if (_suppressOnChange) return;

              if (_editingElementId != null) {
                try {
                  final element = _elements.firstWhere(
                    (e) => e.id == _editingElementId,
                  );
                  element.text = value;
                } catch (e) {}
              }
              _saveState();
            },

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
