import 'package:flutter/material.dart';
import 'package:vector_epub_reader/vector_epub_reader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VECTOR Epub Reader Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'VECTOR Epub Reader Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EpubReader(
                              epubUrl:
                                  'https://dreamlab.sgp1.cdn.digitaloceanspaces.com/ebookfile/1733925339764-898454218-Business-Model-Innovation-Concepts-Analysis-and-Cases-Afuah-Allan-Afuah-Allan-ZLibrary.epub',
                              backgroundColor: Colors.grey[200],
                              textColor: Colors.black,
                              settingsBackgroundColor: Colors.white,
                              settingsTextColor: Colors.black,
                              appBarColor: Colors.blue,
                              appBarTextColor: Colors.white,
                              drawerBackgroundColor: Colors.grey[300],
                              drawerTextColor: Colors.black,
                              navigationBarColor: Colors.blue,
                              navigationTextColor: Colors.white,
                              appBarIconColor: Colors.white)),
                    );
                  },
                  child: const Text('Open Epub with Custom Colors')),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EpubReader(
                                epubUrl:
                                    'https://dreamlab.sgp1.cdn.digitaloceanspaces.com/ebookfile/1733925339764-898454218-Business-Model-Innovation-Concepts-Analysis-and-Cases-Afuah-Allan-Afuah-Allan-ZLibrary.epub',
                              )),
                    );
                  },
                  child: const Text('Open Epub with Default Colors')),
            ),
          ],
        ),
      ),
    );
  }
}
