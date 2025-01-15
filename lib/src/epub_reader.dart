import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/dom.dart' as dom;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vector_epub_reader/src/models/epub_chapter.dart';
import 'package:vector_epub_reader/src/utils/extensions.dart';

class EpubReader extends StatefulWidget {
  final String epubUrl;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? settingsBackgroundColor;
  final Color? settingsTextColor;
  final Color? appBarColor;
  final Color? appBarTextColor;
  final Color? drawerBackgroundColor;
  final Color? drawerTextColor;
  final Color? navigationBarColor;
  final Color? navigationTextColor;
  final Color? appBarIconColor;

  const EpubReader({
    Key? key,
    required this.epubUrl,
    this.backgroundColor,
    this.textColor,
    this.settingsBackgroundColor,
    this.settingsTextColor,
    this.appBarColor,
    this.appBarTextColor,
    this.drawerBackgroundColor,
    this.drawerTextColor,
    this.navigationBarColor,
    this.navigationTextColor,
    this.appBarIconColor,
  }) : super(key: key);

  @override
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  List<EpubChapter> _chapters = [];
  int _currentChapter = 0;
  bool _isLoading = true;
  String? _error;
  final PageController _pageController = PageController();
  String _bookTitle = 'EPUB Reader';
  Uint8List? _coverImage;
  // Settings values with ValueNotifier
  final _fontSizeNotifier = ValueNotifier<double>(18.0);
  final _lineHeightNotifier = ValueNotifier<double>(1.6);
  final _contentPaddingNotifier = ValueNotifier<double>(16.0);
  bool _isFullScreen = false;
  bool _showSettings = false;
  // Default settings
  final double _defaultFontSize = 18.0;
  final double _defaultLineHeight = 1.6;
  final double _defaultContentPadding = 16.0;
  // Add the ScrollController for the Drawer
  final ScrollController _scrollController = ScrollController();

  Color get _backgroundColor =>
      widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

  Color get _textColor =>
      widget.textColor ??
      Theme.of(context).textTheme.bodyMedium?.color ??
      Colors.black;
  Color get _settingsBackgroundColor =>
      widget.settingsBackgroundColor ?? Theme.of(context).cardColor;

  Color get _settingsTextColor =>
      widget.settingsTextColor ??
      Theme.of(context).textTheme.bodyMedium?.color ??
      Colors.black;

  Color get _appBarColor =>
      widget.appBarColor ??
      Theme.of(context).appBarTheme.backgroundColor ??
      Theme.of(context).primaryColor;

  Color get _appBarTextColor =>
      widget.appBarTextColor ??
      Theme.of(context).appBarTheme.titleTextStyle?.color ??
      Colors.white;

  Color get _drawerBackgroundColor =>
      widget.drawerBackgroundColor ?? Theme.of(context).canvasColor;

  Color get _drawerTextColor =>
      widget.drawerTextColor ??
      Theme.of(context).textTheme.bodyMedium?.color ??
      Colors.black;

  Color get _navigationBarColor =>
      widget.navigationBarColor ??
      Theme.of(context).bottomAppBarTheme.color ??
      Theme.of(context).primaryColor;

  Color get _navigationTextColor =>
      widget.navigationTextColor ??
      Theme.of(context).textTheme.bodyMedium?.color ??
      Colors.white;

  Color get _appBarIconColor =>
      widget.appBarIconColor ??
      Theme.of(context).appBarTheme.iconTheme?.color ??
      Colors.white;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadEpub();
    // add listener to notify the UI change when setting is updated
    _fontSizeNotifier.addListener(_saveSettings);
    _lineHeightNotifier.addListener(_saveSettings);
    _contentPaddingNotifier.addListener(_saveSettings);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSizeNotifier.value = prefs.getDouble('fontSize') ?? _defaultFontSize;
      _lineHeightNotifier.value =
          prefs.getDouble('lineHeight') ?? _defaultLineHeight;
      _contentPaddingNotifier.value =
          prefs.getDouble('contentPadding') ?? _defaultContentPadding;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSizeNotifier.value);
    await prefs.setDouble('lineHeight', _lineHeightNotifier.value);
    await prefs.setDouble('contentPadding', _contentPaddingNotifier.value);
  }

  Future<void> _loadEpub() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _chapters = [];
      _coverImage = null;
    });
    try {
      final epubData = await _fetchEpubData(widget.epubUrl);
      final parsedData = await compute(_parseEpub, epubData);
      setState(() {
        _bookTitle = parsedData['bookTitle'];
        _chapters = parsedData['chapters'];
        _coverImage = parsedData['coverImage'];
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _chapters = [];
        _coverImage = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function for network call
  Future<Uint8List> _fetchEpubData(String epubUrl) async {
    final response = await http.get(Uri.parse(epubUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download EPUB file: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  // Function that runs on background thread
  static Map<String, dynamic> _parseEpub(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final containerEntry = archive.files.firstWhere(
        (file) => file.name == 'META-INF/container.xml',
        orElse: () => throw Exception('Invalid EPUB: container.xml not found'),
      );
      final containerXml =
          XmlDocument.parse(utf8.decode(containerEntry.content));
      final opfPath = containerXml
          .findAllElements('rootfile')
          .firstWhere((element) => element.getAttribute('full-path') != null)
          .getAttribute('full-path');
      if (opfPath == null) {
        throw Exception('Invalid EPUB: OPF path not found');
      }
      final opfEntry = archive.files.firstWhere(
        (file) => file.name == opfPath,
        orElse: () => throw Exception('Invalid EPUB: OPF file not found'),
      );
      final opfXml = XmlDocument.parse(utf8.decode(opfEntry.content));

      // Get book title
      final titleElement = opfXml.findAllElements('dc:title').firstOrNull ??
          opfXml.findAllElements('title').firstOrNull;
      final bookTitle = titleElement?.innerText.trim() ?? 'EPUB Reader';

      final spine = opfXml.findAllElements('spine').first;
      final manifest = opfXml.findAllElements('manifest').first;

      // Extract images
      final Map<String, dynamic> images = {};
      Uint8List? coverImage;
      String? coverId;

      // 1. Try to find cover id using metadata tag
      final coverMeta = opfXml
          .findAllElements('meta')
          .firstWhereOrNull((meta) => meta.getAttribute('name') == 'cover');
      if (coverMeta != null) {
        coverId = coverMeta.getAttribute('content');
      }

      // 2. Try to find cover from manifest entry with properties attribute if coverId is not found via meta
      if (coverId == null) {
        final manifestCover = manifest.findAllElements('item').firstWhereOrNull(
              (item) =>
                  item.getAttribute('properties')?.contains('cover-image') ==
                  true,
            );
        coverId = manifestCover?.getAttribute('id');
      }

      // 3. If we found the ID, load the image
      if (coverId != null) {
        final coverItem = manifest
            .findAllElements('item')
            .firstWhereOrNull((item) => item.getAttribute('id') == coverId);
        final href = coverItem?.getAttribute('href');
        if (href != null) {
          final imagePath = _resolveImagePath(opfPath, href);
          final normalizedImagePath = _normalizePath(imagePath);
          final imageEntry = archive.files.firstWhereOrNull(
            (file) => _normalizePath(file.name) == normalizedImagePath,
          );
          if (imageEntry != null) {
            coverImage = Uint8List.fromList(imageEntry.content);
          }
        }
      }

      for (final item in manifest.findAllElements('item')) {
        final mediaType = item.getAttribute('media-type');
        final href = item.getAttribute('href');
        if (mediaType?.startsWith('image/') == true && href != null) {
          final imagePath = _resolveImagePath(opfPath, href);
          final normalizedImagePath = _normalizePath(imagePath);
          final imageEntry = archive.files.firstWhereOrNull(
            (file) => _normalizePath(file.name) == normalizedImagePath,
          );
          if (imageEntry != null) {
            images[href] = {
              "content": Uint8List.fromList(imageEntry.content),
              "mimeType": mediaType
            };
          }
        }
      }

      // Create HTML href to file path mapping
      final Map<String, String> idToPath = {};
      for (final item in manifest.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          idToPath[id] = href;
        }
      }

      // Process chapters
      final List<EpubChapter> chapters = [];
      int chapterIndex = 0;
      for (final itemref in spine.findAllElements('itemref')) {
        final idref = itemref.getAttribute('idref');
        if (idref != null && idToPath.containsKey(idref)) {
          final href = idToPath[idref]!;
          final path = _resolveImagePath(opfPath, href);
          final normalizedPath = _normalizePath(path);
          final entry = archive.files.firstWhereOrNull(
            (file) => _normalizePath(file.name) == normalizedPath,
          );
          if (entry == null) {
            continue;
          }
          var content = utf8.decode(entry.content);
          String title = '';
          try {
            final doc = XmlDocument.parse(content);
            var element = doc.findAllElements('h1').firstOrNull;
            if (element == null)
              element = doc.findAllElements('h2').firstOrNull;
            if (element == null)
              element = doc.findAllElements('title').firstOrNull;
            if (element != null) {
              title = element.innerText.trim();
            } else {
              // If we dont found h1, h2 or title tag, we fallback to searching p tags
              for (final element in doc.findAllElements('p')) {
                final text = element.innerText.trim();
                if (text.length > 10 && text.length < 200) {
                  title = text;
                  break;
                }
              }
            }
          } catch (e) {}
          // Fallback title if nothing found
          if (title.isEmpty) {
            title = 'Chapter ${chapterIndex + 1}';
          }
          // Replace image sources with base64 data
          content = content.replaceAllMapped(
            RegExp(r'<img[^>]+src="([^"]+)"'),
            (match) {
              final imgSrc = match.group(1)!;
              String? newSrc;
              final normalizedImageSrc = _normalizePath(imgSrc);
              for (final key in images.keys) {
                if (_normalizePath(key) == normalizedImageSrc) {
                  final base64Image = base64Encode(images[key]['content']!);
                  final mimeType = images[key]['mimeType'] ?? 'image/jpeg';
                  newSrc = 'data:$mimeType;base64,$base64Image';
                  break;
                }
              }
              return newSrc != null
                  ? match.group(0)!.replaceAll(imgSrc, newSrc)
                  : match.group(0)!;
            },
          );
          //remove style for each tag for prevent conflict with flutter_html style
          content = content.replaceAll(RegExp(r'style="[^"]*"'), '');

          chapters.add(EpubChapter(
            title: title,
            content: content,
            id: normalizedPath,
          ));
          chapterIndex++;
        }
      }

      return {
        'bookTitle': bookTitle,
        'chapters': chapters,
        'images': images,
        'coverImage': coverImage
      };
    } on Exception {
      rethrow;
    }
  }

  static String _resolveImagePath(String opfPath, String href) {
    if (opfPath.isEmpty) {
      return href;
    }
    final lastSlashIndex = opfPath.lastIndexOf('/');
    if (lastSlashIndex == -1) {
      return href;
    }
    final basePath = opfPath.substring(0, lastSlashIndex);
    return '$basePath/$href'.replaceAll('//', '/');
  }

  static String _normalizePath(String path) {
    if (path.isEmpty) {
      return path;
    }
    try {
      final normalizedPath = path.replaceAll('\\', '/').replaceAll('//', '/');
      return Uri.decodeComponent(normalizedPath);
    } catch (e) {
      return path.replaceAll('\\', '/').replaceAll('//', '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: _isFullScreen
            ? null
            : AppBar(
                backgroundColor: _appBarColor,
                iconTheme: IconThemeData(color: _appBarIconColor),
                title: Text(_isLoading ? 'Loading...' : _bookTitle,
                    style: TextStyle(color: _appBarTextColor)),
                actions: [
                  IconButton(
                    icon: Icon(Icons.list, color: _appBarIconColor),
                    onPressed: () {
                      _showChapterDrawer(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(_showSettings ? Icons.close : Icons.settings,
                        color: _appBarIconColor),
                    onPressed: () {
                      setState(() {
                        _showSettings = !_showSettings;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                        _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: _appBarIconColor),
                    onPressed: () {
                      setState(() {
                        _isFullScreen = !_isFullScreen;
                      });
                    },
                  ),
                ],
              ),
        body: GestureDetector(
            onTap: () {
              if (_isFullScreen) {
                setState(() {
                  _isFullScreen = false;
                });
              }
            },
            child: Stack(
              children: [
                _buildBody(),
                if (_showSettings) _buildSettingsOverlay(),
              ],
            )),
        bottomNavigationBar: _isFullScreen ? null : _buildNavigationBar());
  }

  void _showChapterDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        //scroll to current chapter when drawer open
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentChapter();
        });
        return _buildDrawer();
      },
    );
  }

  //Function to scroll to current chapter
  void _scrollToCurrentChapter() {
    if (_chapters.isNotEmpty) {
      _scrollController.animateTo(
        _currentChapter * 50.0, // Estimate each ListTile height to 50.0
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildSettingsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: _settingsBackgroundColor,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _settingsTextColor)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSettings = false;
                    });
                  },
                ),
              ],
            ),
            ValueListenableBuilder(
              valueListenable: _fontSizeNotifier,
              builder: (context, fontSize, _) {
                return _buildSettingSlider(
                  label: 'Font Size',
                  value: fontSize,
                  min: 12.0,
                  max: 30.0,
                  divisions: 100,
                  onChanged: (newValue) => _fontSizeNotifier.value = newValue,
                  textColor: _settingsTextColor,
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _lineHeightNotifier,
              builder: (context, lineHeight, _) {
                return _buildSettingSlider(
                  label: 'Line Height',
                  value: lineHeight,
                  min: 1.0,
                  max: 3.0,
                  divisions: 100,
                  onChanged: (newValue) => _lineHeightNotifier.value = newValue,
                  textColor: _settingsTextColor,
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _contentPaddingNotifier,
              builder: (context, contentPadding, _) {
                return _buildSettingSlider(
                  label: 'Content Padding',
                  value: contentPadding,
                  min: 8.0,
                  max: 32.0,
                  divisions: 100,
                  onChanged: (newValue) =>
                      _contentPaddingNotifier.value = newValue,
                  textColor: _settingsTextColor,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: _resetSettings,
                child: const Text('Reset to Default'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    required Color textColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: textColor)),
        ),
        SizedBox(
          width: 150,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? 100,
            onChanged: (newValue) {
              onChanged(newValue);
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(value.toStringAsFixed(1),
              style: TextStyle(color: textColor)),
        ),
      ],
    );
  }

  void _resetSettings() {
    _fontSizeNotifier.value = _defaultFontSize;
    _lineHeightNotifier.value = _defaultLineHeight;
    _contentPaddingNotifier.value = _defaultContentPadding;
  }

  Widget _buildDrawer() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadEpub, child: const Text('Retry'))
            ],
          ),
        ),
      );
    }
    return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _chapters.length + (_coverImage != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (_coverImage != null && index == 0) {
            return Container(
                height: 200,
                decoration: BoxDecoration(
                    image: DecorationImage(
                        image: MemoryImage(_coverImage!), fit: BoxFit.cover)));
          }
          final chapterIndex = index - (_coverImage != null ? 1 : 0);
          if (_chapters.length > chapterIndex) {
            return Container(
              color: _drawerBackgroundColor,
              child: ListTile(
                title: Text(
                  _chapters[chapterIndex].title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _drawerTextColor),
                ),
                selected: chapterIndex == _currentChapter,
                onTap: () {
                  setState(() {
                    _currentChapter = chapterIndex;
                    _isFullScreen = false; // Add this line
                  });
                  _pageController.jumpToPage(index);
                  Navigator.pop(context);
                },
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        });
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadEpub, child: const Text('Retry'))
            ],
          ),
        ),
      );
    }
    if (_chapters.isEmpty) {
      return const Center(child: Text('No content available'));
    }
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentChapter = (index - (_coverImage != null ? 1 : 0))
              .clamp(0, _chapters.length - 1);
        });
      },
      itemCount: _chapters.length + (_coverImage != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (_coverImage != null && index == 0) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: MemoryImage(_coverImage!),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        final chapterIndex = index - (_coverImage != null ? 1 : 0);
        return Container(
          color: _backgroundColor,
          // Use default white background
          child: ValueListenableBuilder(
            valueListenable: _contentPaddingNotifier,
            builder: (context, contentPadding, _) => SingleChildScrollView(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                children: [
                  if (_chapters[chapterIndex].content.isNotEmpty)
                    ValueListenableBuilder<double>(
                      valueListenable: _fontSizeNotifier,
                      builder: (context, fontSize, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _lineHeightNotifier,
                          builder: (context, lineHeight, _) {
                            return SelectionArea(
                              child: Html(
                                data: _chapters[chapterIndex].content,
                                onLinkTap: (String? url,
                                    Map<String, String> attributes,
                                    dom.Element? element) {
                                  if (url != null) {
                                    _handleInternalLink(url);
                                  }
                                },
                                style: {
                                  "body": Style(
                                    color: _textColor,
                                    fontSize: FontSize(fontSize),
                                    lineHeight: LineHeight(lineHeight),
                                  ),
                                  "img": Style(
                                    alignment: Alignment.center,
                                    width: Width(
                                        MediaQuery.of(context).size.width - 32),
                                  ),
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  if (chapterIndex < _chapters.length - 1)
                    const Divider(
                      height: 24.0,
                      // Adjust as needed
                      thickness: 1,
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleInternalLink(String url) async {
    // Handle external URLs (http, https, www)
    if (url.startsWith('http') || url.startsWith('www')) {
      if (kIsWeb) {
      } else {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open URL: $url')),
            );
          }
        }
      }
      return;
    }

    // Parse the internal link
    String? filename;
    String? fragment;

    // Check if the URL contains a fragment identifier
    final fragmentIndex = url.indexOf('#');
    if (fragmentIndex != -1) {
      // If there's content before the #, it's the filename
      if (fragmentIndex > 0) {
        filename = url.substring(0, fragmentIndex);
      }
      fragment = url.substring(fragmentIndex + 1);
    } else {
      // If no #, treat the entire URL as a filename
      filename = url;
    }

    // First try to find by exact ID match
    if (fragment != null) {
      final index = _chapters.indexWhere((chapter) {
        return chapter.id?.endsWith('#$fragment') == true;
      });
      if (index != -1) {
        _pageController.jumpToPage(index + (_coverImage != null ? 1 : 0));
        setState(() {
          _currentChapter = index;
        });
        return;
      }
    }

    // If fragment search failed, try filename match
    if (filename != null) {
      final normalizedFilename = _normalizePath(filename);
      final index = _chapters.indexWhere((chapter) {
        return chapter.id?.contains(normalizedFilename) == true;
      });
      if (index != -1) {
        _pageController.jumpToPage(index + (_coverImage != null ? 1 : 0));
        setState(() {
          _currentChapter = index;
        });
        return;
      }
    }
  }

  Widget _buildNavigationBar() {
    if (_chapters.isEmpty) return const SizedBox.shrink();
    return BottomAppBar(
      color: _navigationBarColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentChapter > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() {
                        _currentChapter = (_currentChapter - 1)
                            .clamp(0, _chapters.length - 1);
                      });
                    }
                  : null,
              color: _navigationTextColor,
            ),
            GestureDetector(
              onTap: () {
                _showChapterDrawer(context);
              },
              child: Text(
                '${_currentChapter + 1}/${_chapters.length}',
                style: TextStyle(color: _navigationTextColor),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentChapter < _chapters.length - 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() {
                        _currentChapter = (_currentChapter + 1)
                            .clamp(0, _chapters.length - 1);
                      });
                    }
                  : null,
              color: _navigationTextColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fontSizeNotifier.dispose();
    _lineHeightNotifier.dispose();
    _contentPaddingNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
