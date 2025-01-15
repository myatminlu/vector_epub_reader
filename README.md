Okay, let's craft a good `README.md` and a basic `LICENSE` file for your `vector_epub_reader` package. I'll provide you with examples you can adapt for your project.

**1. `README.md`**

```markdown
# vector_epub_reader

A customizable Flutter package for reading EPUB files.

This package provides a widget that allows you to easily display EPUB books in your Flutter applications. It supports:

-   Parsing and rendering EPUB content.
-   Navigation between chapters.
-   Customization of colors.
-   Font size, line height, and content padding adjustments.
-   Fullscreen mode.
-   Settings persistence.

## Installation

Add `vector_epub_reader` to your `pubspec.yaml` file:

```yaml
dependencies:
  vector_epub_reader: latest_version
```

Then, run:

```bash
flutter pub get
```

## Usage

Import the package in your dart code:

```dart
import 'package:vector_epub_reader/vector_epub_reader.dart';
```

Use the `EpubReader` widget:

```dart
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => EpubReader(
      epubUrl: 'URL_TO_YOUR_EPUB_FILE',
      backgroundColor: Colors.grey[200],
      textColor: Colors.black,
      chapterTitleColor: Colors.blue,
      settingsBackgroundColor: Colors.white,
      settingsTextColor: Colors.black,
      appBarColor: Colors.blue,
      appBarTextColor: Colors.white,
      drawerBackgroundColor: Colors.grey[300],
      drawerTextColor: Colors.black,
      navigationBarColor: Colors.blue,
      navigationTextColor: Colors.white,
      appBarIconColor: Colors.white,
    )),
  );
```

## Customization

The `EpubReader` widget has several properties you can use to customize the look:

-   **`epubUrl`:** The URL of the EPUB file to load.
-   **`backgroundColor`:** Background color of the reader.
-   **`textColor`:** Color of the text in the content.
-   **`chapterTitleColor`:** Color of the chapter titles.
-   **`settingsBackgroundColor`:** Background color of the settings overlay.
-   **`settingsTextColor`:** Text color for the settings overlay.
-   **`appBarColor`:** Background color of the AppBar.
-    **`appBarTextColor`:** Text color of the AppBar title.
-   **`drawerBackgroundColor`:** Background color of the chapter drawer.
-   **`drawerTextColor`:** Text color of the chapter titles in the drawer.
-    **`navigationBarColor`:** Background color of the navigation bar.
-   **`navigationTextColor`:** Text color for the navigation bar items.
-   **`appBarIconColor`:** Color of the icons on the AppBar.
-    **`appBarIconDisabledColor`:** Color of the disabled icons on the AppBar.

Users can also customize font size, line height, and content padding using the settings modal.

## Example

For a more detailed example of how to use the package, see the `example/` folder in the repository.

## Contributing

Contributions are welcome! Please open issues or submit pull requests on the [GitHub repository](https://github.com/myatminlu/vector_epub_reader).

