// Dart imports:
import 'dart:async';
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:rounded_background_text/rounded_background_text.dart';

// Project imports:
import 'package:pro_image_editor/mixins/converted_callbacks.dart';
import 'package:pro_image_editor/mixins/converted_configs.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../mixins/editor_configs_mixin.dart';
import '../../utils/theme_functions.dart';
import '../../widgets/bottom_sheets_header_row.dart';
import '../../widgets/platform_popup_menu.dart';
import 'widgets/text_editor_bottom_bar.dart';

/// A StatefulWidget that provides a text editing interface for adding and editing text layers.
class TextEditor extends StatefulWidget with SimpleConfigsAccess {
  @override
  final ProImageEditorConfigs configs;

  @override
  final ProImageEditorCallbacks callbacks;

  /// A unique hero tag for the image.
  final String? heroTag;

  /// The theme configuration for the editor.
  final ThemeData theme;

  /// The text layer data to be edited, if any.
  final TextLayerData? layer;

  /// Creates a `TextEditor` widget.
  ///
  /// The [heroTag], [layer], [i18n], [customWidgets], and [imageEditorTheme] parameters are required.
  const TextEditor({
    super.key,
    this.heroTag,
    this.layer,
    this.callbacks = const ProImageEditorCallbacks(),
    this.configs = const ProImageEditorConfigs(),
    required this.theme,
  });

  @override
  createState() => TextEditorState();
}

/// The state class for the `TextEditor` widget.
class TextEditorState extends State<TextEditor>
    with
        ImageEditorConvertedConfigs,
        ImageEditorConvertedCallbacks,
        SimpleConfigsAccessState {
  late final StreamController _rebuildController;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Color primaryColor = Colors.black;
  late TextAlign align;
  late LayerBackgroundMode backgroundColorMode;
  late double _fontScale;
  late TextStyle selectedTextStyle;
  int _numLines = 0;
  double colorPosition = 0;

  @override
  void initState() {
    super.initState();
    _rebuildController = StreamController.broadcast();
    align = textEditorConfigs.initialTextAlign;
    _fontScale = textEditorConfigs.initFontScale;
    backgroundColorMode = textEditorConfigs.initialBackgroundColorMode;

    selectedTextStyle = widget.layer?.textStyle ??
        textEditorConfigs.customTextStyles?.first ??
        const TextStyle();
    _initializeFromLayer();
    _setupTextControllerListener();
  }

  @override
  void dispose() {
    _rebuildController.close();
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void setState(void Function() fn) {
    _rebuildController.add(null);
    super.setState(fn);
  }

  /// Initializes the text editor from the provided text layer data.
  void _initializeFromLayer() {
    if (widget.layer != null) {
      _textCtrl.text = widget.layer!.text;
      align = widget.layer!.align;
      _fontScale = widget.layer!.fontScale;
      backgroundColorMode = widget.layer!.colorMode!;
      primaryColor = backgroundColorMode == LayerBackgroundMode.background
          ? widget.layer!.background
          : widget.layer!.color;
      _numLines = '\n'.allMatches(_textCtrl.text).length + 1;
      colorPosition = widget.layer!.colorPickerPosition ?? 0;
    }
  }

  /// Sets up a listener to update the number of lines when text changes.
  void _setupTextControllerListener() {
    _textCtrl.addListener(() {
      setState(() {
        _numLines = '\n'.allMatches(_textCtrl.text).length + 1;
        textEditorCallbacks?.handleUpdateUI();
      });
    });
  }

  /// Calculates the contrast color for a given color.
  Color _getContrastColor(Color color) {
    int d = color.computeLuminance() > 0.5 ? 0 : 255;

    return Color.fromARGB(color.alpha, d, d, d);
  }

  /// Gets the text color based on the selected color mode.
  Color get _getTextColor {
    return backgroundColorMode == LayerBackgroundMode.onlyColor
        ? primaryColor
        : backgroundColorMode == LayerBackgroundMode.backgroundAndColor
            ? primaryColor
            : backgroundColorMode == LayerBackgroundMode.background
                ? _getContrastColor(primaryColor)
                : primaryColor;
  }

  /// Gets the background color based on the selected color mode.
  Color get _getBackgroundColor {
    return backgroundColorMode == LayerBackgroundMode.onlyColor
        ? Colors.transparent
        : backgroundColorMode == LayerBackgroundMode.backgroundAndColor
            ? _getContrastColor(primaryColor)
            : backgroundColorMode == LayerBackgroundMode.background
                ? primaryColor
                : _getContrastColor(primaryColor).withOpacity(0.5);
  }

  /// Gets the text font size based on the selected font scale.
  double get _getTextFontSize {
    return textEditorConfigs.initFontSize * _fontScale;
  }

  /// Toggles the text alignment between left, center, and right.
  void toggleTextAlign() {
    setState(() {
      align = align == TextAlign.left
          ? TextAlign.center
          : align == TextAlign.center
              ? TextAlign.right
              : TextAlign.left;
    });
    textEditorCallbacks?.handleTextAlignChanged(align);
  }

  /// Toggles the background mode between various color modes.
  void toggleBackgroundMode() {
    setState(() {
      backgroundColorMode = backgroundColorMode == LayerBackgroundMode.onlyColor
          ? LayerBackgroundMode.backgroundAndColor
          : backgroundColorMode == LayerBackgroundMode.backgroundAndColor
              ? LayerBackgroundMode.background
              : backgroundColorMode == LayerBackgroundMode.background
                  ? LayerBackgroundMode.backgroundAndColorWithOpacity
                  : LayerBackgroundMode.onlyColor;
    });
    textEditorCallbacks?.handleBackgroundModeChanged(backgroundColorMode);
  }

  /// Gets the current font scale.
  double get fontScale => _fontScale;

  /// Sets the font scale to a new value.
  ///
  /// The new value is adjusted to one decimal place before being set.
  /// After setting the new value, the state is updated and the
  /// [textEditorCallbacks] are notified of the change.
  ///
  /// [value] - The new font scale value.
  set fontScale(double value) {
    _fontScale = (value * 10).ceilToDouble() / 10;
    setState(() {});
    textEditorCallbacks?.handleFontScaleChanged(value);
  }

  /// Displays a range slider for adjusting the line width of the painting tool.
  ///
  /// This method shows a range slider in a modal bottom sheet for adjusting the line width of the painting tool.
  void openFontScaleBottomSheet() {
    final presetFontScale = _fontScale;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          imageEditorTheme.paintingEditor.lineWidthBottomSheetColor,
      builder: (BuildContext context) {
        return Material(
          color: Colors.transparent,
          textStyle: platformTextStyle(context, designMode),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: StatefulBuilder(builder: (context, setState) {
                void updateFontScaleScale(double value) {
                  fontScale = value;
                  setState(() {});
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BottomSheetHeaderRow(
                      title: '${i18n.textEditor.fontScale} ${_fontScale}x',
                      theme: widget.theme,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider.adaptive(
                            max: textEditorConfigs.maxFontScale,
                            min: textEditorConfigs.minFontScale,
                            divisions: (textEditorConfigs.maxFontScale -
                                    textEditorConfigs.minFontScale) ~/
                                0.1,
                            value: _fontScale,
                            onChanged: updateFontScaleScale,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconTheme(
                          data: Theme.of(context).primaryIconTheme,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: _fontScale != presetFontScale
                                ? IconButton(
                                    onPressed: () {
                                      updateFontScaleScale(presetFontScale);
                                    },
                                    icon: Icon(icons.textEditor.resetFontScale),
                                  )
                                : IconButton(
                                    key: UniqueKey(),
                                    color: Colors.transparent,
                                    onPressed: null,
                                    icon: Icon(icons.textEditor.resetFontScale),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  /// Update the current text style.
  void setTextStyle(TextStyle style) {
    setState(() {
      selectedTextStyle = style;
      textEditorCallbacks?.handleUpdateUI();
    });
  }

  /// Closes the editor without applying changes.
  void close() {
    Navigator.pop(context);
    textEditorCallbacks?.handleCloseEditor();
  }

  /// Handles the "Done" action, either by applying changes or closing the editor.
  void done() {
    if (_textCtrl.text.trim().isNotEmpty) {
      Navigator.of(context).pop(
        TextLayerData(
          text: _textCtrl.text.trim(),
          background: _getBackgroundColor,
          color: _getTextColor,
          align: align,
          fontScale: _fontScale,
          colorMode: backgroundColorMode,
          colorPickerPosition: colorPosition,
          textStyle: selectedTextStyle,
          // fontFamily: 'Roboto',
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
    textEditorCallbacks?.handleDone();
  }

  /// Handles changes in the selected color.
  void colorChanged(Color color) {
    setState(() {
      primaryColor = color;
      textEditorCallbacks?.handleColorChanged(color.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Theme(
          data: widget.theme.copyWith(
              tooltipTheme:
                  widget.theme.tooltipTheme.copyWith(preferBelow: true)),
          child: Scaffold(
            backgroundColor: imageEditorTheme.textEditor.background,
            appBar: _buildAppBar(constraints),
            body: _buildBody(),
            bottomNavigationBar: _buildBottomBar(),
          ),
        );
      },
    );
  }

  /// Builds the app bar for the text editor.
  PreferredSizeWidget? _buildAppBar(BoxConstraints constraints) {
    if (customWidgets.textEditor.appBar != null) {
      return customWidgets.textEditor.appBar!
          .call(this, _rebuildController.stream);
    }
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: imageEditorTheme.textEditor.appBarBackgroundColor,
      foregroundColor: imageEditorTheme.textEditor.appBarForegroundColor,
      actions: [
        IconButton(
          tooltip: i18n.textEditor.back,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(icons.backButton),
          onPressed: close,
        ),
        const Spacer(),
        if (constraints.maxWidth >= 300) ...[
          if (textEditorConfigs.canToggleTextAlign)
            IconButton(
              key: const ValueKey('TextAlignIconButton'),
              tooltip: i18n.textEditor.textAlign,
              onPressed: toggleTextAlign,
              icon: Icon(align == TextAlign.left
                  ? icons.textEditor.alignLeft
                  : align == TextAlign.right
                      ? icons.textEditor.alignRight
                      : icons.textEditor.alignCenter),
            ),
          if (textEditorConfigs.canChangeFontScale)
            IconButton(
              key: const ValueKey('BackgroundModeFontScaleButton'),
              tooltip: i18n.textEditor.fontScale,
              onPressed: openFontScaleBottomSheet,
              icon: Icon(icons.textEditor.fontScale),
            ),
          if (textEditorConfigs.canToggleBackgroundMode)
            IconButton(
              key: const ValueKey('BackgroundModeColorIconButton'),
              tooltip: i18n.textEditor.backgroundMode,
              onPressed: toggleBackgroundMode,
              icon: Icon(icons.textEditor.backgroundMode),
            ),
          const Spacer(),
          _buildDoneBtn(),
        ] else ...[
          const Spacer(),
          _buildDoneBtn(),
          PlatformPopupBtn(
            designMode: designMode,
            title: i18n.textEditor.smallScreenMoreTooltip,
            options: [
              if (textEditorConfigs.canToggleTextAlign)
                PopupMenuOption(
                  label: i18n.textEditor.textAlign,
                  icon: Icon(align == TextAlign.left
                      ? icons.textEditor.alignLeft
                      : align == TextAlign.right
                          ? icons.textEditor.alignRight
                          : icons.textEditor.alignCenter),
                  onTap: () {
                    toggleTextAlign();
                    if (designMode == ImageEditorDesignModeE.cupertino) {
                      Navigator.pop(context);
                    }
                  },
                ),
              if (textEditorConfigs.canChangeFontScale)
                PopupMenuOption(
                  label: i18n.textEditor.fontScale,
                  icon: Icon(icons.textEditor.fontScale),
                  onTap: () {
                    openFontScaleBottomSheet();
                    if (designMode == ImageEditorDesignModeE.cupertino) {
                      Navigator.pop(context);
                    }
                  },
                ),
              if (textEditorConfigs.canToggleBackgroundMode)
                PopupMenuOption(
                  label: i18n.textEditor.backgroundMode,
                  icon: Icon(icons.textEditor.backgroundMode),
                  onTap: () {
                    toggleBackgroundMode();
                    if (designMode == ImageEditorDesignModeE.cupertino) {
                      Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds the bottom navigation bar of the painting editor.
  /// Returns a [Widget] representing the bottom navigation bar.
  Widget? _buildBottomBar() {
    if (customWidgets.textEditor.bottomBar != null) {
      return customWidgets.textEditor.bottomBar!
          .call(this, _rebuildController.stream);
    }

    if (isDesktop &&
        widget.configs.textEditorConfigs.customTextStyles?.isNotEmpty ==
            false) {
      return const SizedBox(height: kBottomNavigationBarHeight);
    }

    return null;
  }

  /// Builds the body of the text editor.
  Widget _buildBody() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: done,
      child: Stack(
        children: [
          if (customWidgets.textEditor.bodyItems != null)
            ...customWidgets.textEditor.bodyItems!(
              this,
              _rebuildController.stream,
            ),
          _buildTextField(),
          _buildColorPicker(),
          if (textEditorConfigs.showSelectFontStyleBottomBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: kBottomNavigationBarHeight,
              child: TextEditorBottomBar(
                configs: widget.configs,
                selectedStyle: selectedTextStyle,
                onFontChange: setTextStyle,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds and returns an IconButton for applying changes.
  Widget _buildDoneBtn() {
    return IconButton(
      key: const ValueKey('TextEditorDoneButton'),
      tooltip: i18n.textEditor.done,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      icon: Icon(icons.applyChanges),
      iconSize: 28,
      onPressed: done,
    );
  }

  Widget _buildColorPicker() {
    if (customWidgets.textEditor.colorPicker != null) {
      return customWidgets.textEditor.colorPicker!.call(
            this,
            _rebuildController.stream,
            selectedTextStyle.color ?? primaryColor,
            colorChanged,
          ) ??
          const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: BarColorPicker(
          configs: widget.configs,
          length: min(
            350,
            MediaQuery.of(context).size.height -
                MediaQuery.of(context).viewInsets.bottom -
                kToolbarHeight -
                kBottomNavigationBarHeight -
                10 * 2 -
                MediaQuery.of(context).padding.top,
          ),
          onPositionChange: (value) {
            colorPosition = value;
          },
          initPosition: colorPosition,
          initialColor: primaryColor,
          horizontal: false,
          thumbColor: Colors.white,
          cornerRadius: 10,
          pickMode: PickMode.color,
          colorListener: (int value) {
            colorChanged(Color(value));
          },
        ),
      ),
    );
  }

  /// Builds the text field for text input.
  Widget _buildTextField() {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: _getTextFontSize * _numLines * 1.35 + 15,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: widget.heroTag ?? 'Text-Image-Editor-Empty-Hero',
                    createRectTween: (begin, end) =>
                        RectTween(begin: begin, end: end),
                    child: RoundedBackgroundText(
                      _textCtrl.text,
                      backgroundColor: _getBackgroundColor,
                      textAlign: align,
                      style: selectedTextStyle.copyWith(
                        color: _getTextColor,
                        fontSize: _getTextFontSize,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focus,
                      onChanged: textEditorCallbacks?.handleChanged,
                      onEditingComplete:
                          textEditorCallbacks?.handleEditingComplete,
                      onSubmitted: textEditorCallbacks?.handleSubmitted,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      textAlign:
                          _textCtrl.text.isEmpty ? TextAlign.center : align,
                      maxLines: null,
                      cursorColor: imageEditorTheme.textEditor.inputCursorColor,
                      cursorHeight: _getTextFontSize * 1.2,
                      scrollPhysics: const NeverScrollableScrollPhysics(),
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(
                              12, _numLines <= 1 ? 4 : 0, 12, 0),
                          hintText: _textCtrl.text.isEmpty
                              ? i18n.textEditor.inputHintText
                              : '',
                          hintStyle: selectedTextStyle.copyWith(
                            color: imageEditorTheme.textEditor.inputHintColor,
                            fontSize: _getTextFontSize,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          )),
                      style: selectedTextStyle.copyWith(
                        color: Colors.transparent,
                        fontSize: _getTextFontSize,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
